#!/usr/bin/env zsh

set -e

usage() {
	echo "Usage: $0 (options) ..."
	echo "  -f : Path to .env file"
	echo "  -h : Help"
	echo ""
	echo "Example: "
}

while getopts 'e:h' option; do
	case "$option" in
		e)
			ENV_FILE=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
	esac
done

if [ ! -f "${ENV_FILE}" ]; then
	echo "${0}:${LINENO} Missing .env file. Expected it here: ${ENV_FILE}"
	exit 1
else
	source ${ENV_FILE}
fi

[[ -z "${SCRIPTS_DIR}" ]] && echo ".env is missing SCRIPTS_DIR variable" && exit 1
[[ ! -d "${SCRIPTS_DIR}" ]] && echo "SCRIPTS_DIR environment variable is not a directory. Expecting it here ${SCRIPTS_DIR}" && exit 1

[[ -z "${CONTRACTS_DIR}" ]] && echo ".env is missing CONTRACTS_DIR variable" && exit 1

printer() {
	${SCRIPTS_DIR}/printer.sh "$@"
}

download_release() {
	GITHUB_API_TOKEN=$GITHUB_PAT
	# [ "$GITHUB_API_TOKEN" ] || { echo "Error: Please define GITHUB_API_TOKEN variable." >&2; exit 1; }
	# [ $# -ne 4 ] && { echo "Usage: $0 [owner] [repo] [tag] [name]"; exit 1; }
	# [ "$TRACE" ] && set -x
	read owner repo tag name out_path <<<$@

	GH_REPO="https://api.github.com/repos/$owner/$repo"
	AUTH="Authorization: token $GITHUB_API_TOKEN"

	# Validate token.
	curl -o /dev/null -sH "$AUTH" $GH_REPO || { echo "Error: Invalid repo, token or network issue!";  exit 1; }

	# Read asset tags.
	response=$(curl -sH "$AUTH" "$GH_REPO/releases/tags/$tag")

	# Get ID of the asset based on given name.
	eval $(echo "$response" | grep -C3 "name.:.\+$name" | grep -w id | tr : = | tr -cd '[[:alnum:]]=')

	[ "$id" ] || { echo "Error: Failed to get asset id, response: $response" | awk 'length($0)<100' >&2; exit 1; }

	GH_ASSET="$GH_REPO/releases/assets/$id"

	curl --output ${out_path} -LJ -H "Authorization: token $GITHUB_API_TOKEN" -H 'Accept: application/octet-stream' "$GH_ASSET" &>> ${LOG_FILE}
}

download_lockup_release () {
	download_release ${GITHUB_LOCKUP_ORG} ${GITHUB_LOCKUP_REPO} $LOCKUP_VERSION $LOCKUP_RELEASE_ARCHIVE_FILENAME "$LOCKUP_DIR/${LOCKUP_RELEASE_ARCHIVE_FILENAME}"
	tar -xvf ${LOCKUP_DIR}/$LOCKUP_RELEASE_ARCHIVE_FILENAME -C ${LOCKUP_DIR}/ &>> ${LOG_FILE}
}

download_dao_release () {
	download_release ${GITHUB_DAO_ORG} ${GITHUB_DAO_REPO} $DAO_VERSION $DAO_RELEASE_ARCHIVE_FILENAME "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME"
	unzip $DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME -d ${DAO_DIR}/ &>> ${LOG_FILE}
}

DAO_DIR=${CONTRACTS_DIR}/${GITHUB_DAO_REPO}/${DAO_VERSION}
LOCKUP_DIR=${CONTRACTS_DIR}/${GITHUB_LOCKUP_REPO}/${LOCKUP_VERSION}

DAO_RELEASE_ARCHIVE_FILENAME=$DAO_VERSION.zip
LOCKUP_RELEASE_ARCHIVE_FILENAME=contracts_$LOCKUP_VERSION.tar.gz

if [ -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && [ -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] 
then
	printer -n "Smart contract bytecode present, skipping"
else
	printer -t "Downloading smart contract bytecode"
	[ ! -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${LOCKUP_DIR} && download_lockup_release
	[ ! -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${DAO_DIR} && download_dao_release

	printer -s "Retrieved contract bytecode"
fi


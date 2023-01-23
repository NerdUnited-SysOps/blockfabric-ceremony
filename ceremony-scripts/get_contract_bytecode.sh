#!/usr/bin/zsh

set -e

SCRIPTS_DIR=$(dirname ${(%):-%N})
ENV_FILE="${SCRIPTS_DIR}/../.env"

BASE_DIR=${SCRIPTS_DIR}/..
CONTRACTS_DIR=${BASE_DIR}/contracts
UTIL_SCRIPTS_DIR=${SCRIPTS_DIR}/util

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

source ${ENV_FILE}

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

download_bridge_release () {
#	download_release ${GITHUB_BRIDGE_ORG} ${GITHUB_BRIDGE_REPO} $BRIDGE_VERSION $BRIDGE_RELEASE_ARCHIVE_FILENAME "$BRIDGE_DIR/$BRIDGE_RELEASE_ARCHIVE_FILENAME"
#	unzip $BRIDGE_DIR/$BRIDGE_RELEASE_ARCHIVE_FILENAME -d ${BRIDGE_DIR}/ &>> ${LOG_FILE}
	
}

DAO_DIR=${CONTRACTS_DIR}/${GITHUB_DAO_REPO}/${DAO_VERSION}
LOCKUP_DIR=${CONTRACTS_DIR}/${GITHUB_LOCKUP_REPO}/${LOCKUP_VERSION}
BRIDGE_DIR=${CONTRACTS_DIR}/${GITHUB_BRIDGE_REPO}/${BRIDGE_VERSION}

DAO_RELEASE_ARCHIVE_FILENAME=$DAO_VERSION.zip
LOCKUP_RELEASE_ARCHIVE_FILENAME=contracts_$LOCKUP_VERSION.tar.gz
BRIDGE_RELEASE_ARCHIVE_FILENAME=contracts_$BRIDGE_VERSION.tar.gz

if [ -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && [ -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] && [ -f "$BRIDGE_DIR/$BRIDGE_RELEASE_ARCHIVE_FILENAME" ]
then
	printer -n "Smart contract bytecode present, skipping"
else
	printer -t "Downloading smart contract bytecode"
	[ ! -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${LOCKUP_DIR} && download_lockup_release
	[ ! -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${DAO_DIR} && download_dao_release
	#[ ! -f "$BRIDGE_DIR/$BRIDGE_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${BRIDGE_DIR} && download_bridge_release

	printer -s "Retrieved contract bytecode"
fi


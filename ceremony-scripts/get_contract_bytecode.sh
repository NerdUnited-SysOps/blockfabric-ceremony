#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

DAO_DIR=${CONTRACTS_DIR}/sc_dao/${DAO_VERSION}
LOCKUP_DIR=${CONTRACTS_DIR}/sc_lockup/${LOCKUP_VERSION}

DAO_RELEASE_ARCHIVE_FILENAME=$DAO_VERSION.zip
LOCKUP_RELEASE_ARCHIVE_FILENAME=contracts_$LOCKUP_VERSION.tar.gz

download_lockup_release () {
    CURRENT_DIR=$(pwd)
    cd $LOCKUP_DIR
    ${UTIL_SCRIPTS_DIR}/gh_dl_release.sh NerdCoreSdk sc_lockup $LOCKUP_VERSION $LOCKUP_RELEASE_ARCHIVE_FILENAME
    tar -xvf $LOCKUP_RELEASE_ARCHIVE_FILENAME &>> ${LOG_FILE}
    cd $CURRENT_DIR
}

download_dao_release () {
    cd $DAO_DIR

    ${UTIL_SCRIPTS_DIR}/gh_dl_release.sh NerdCoreSdk sc_dao $DAO_VERSION $DAO_RELEASE_ARCHIVE_FILENAME
    unzip $DAO_RELEASE_ARCHIVE_FILENAME &>> ${LOG_FILE}

    cd $CURRENT_DIR
}

${SCRIPTS_DIR}/print_title.sh "Downloading smart contract bytecode" | tee ${LOG_FILE}
[ -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && [ -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] &&  echo -e "ERR: sc_dao ($DAO_VERSION) and sc_lockuip ($LOCKUP_VERSION)_already exist. \nSkipping..."  && exit 17

[ ! -f "$LOCKUP_DIR/$LOCKUP_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${LOCKUP_DIR} && download_lockup_release
[ ! -f "$DAO_DIR/$DAO_RELEASE_ARCHIVE_FILENAME" ] && mkdir -p ${DAO_DIR} && download_dao_release

echo done.

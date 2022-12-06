#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
source $SCRIPT_DIR/../.common.sh

${SCRIPTS_DIR}/printer.sh -s "Execution Complete"

echo ""
echo ""
echo ""
echo ""
echo "    _   ____________  ____  _____"
echo "   / | / / ____/ __ \/ __ \/ ___/"
echo "  /  |/ / __/ / /_/ / / / /\__ \ "
echo " / /|  / /___/ _, _/ /_/ /___/ / "
echo "/_/ |_/_____/_/ |_/_____//____/  "
echo "                                 "
echo ""

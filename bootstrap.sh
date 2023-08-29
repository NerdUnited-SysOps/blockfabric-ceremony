#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version=2.0.0
ceremony_repo_tag=2.0.0
additions_repo_tag=2.0.2
ceremony_os_version=$(cat ${HOME}/version | tail -2)
network=$1
chain=$2
type1=$3
type2=$4
type3=$5
base="${HOME}"
bootstrap=genesis.blockfabric.net
bootstrap_log=$base/ceremony-artifacts/ceremony.log

cd $base
mkdir -p $base/ceremony-artifacts/
clear

########################## Check args
if (( $# < 3 )); then
    echo
    echo "Expected  (1)  network [ mainnet | testnet ] "
    echo "          (2)  chain name"
    echo "          (3)  ceremony type. 1 required, multiple allowed "
    echo "               [ chain | bridge | lockup_swap | halving ]"
    echo
    exit 1
fi

########################## Prep Firefox homepage for block explorer
echo
## Modify Firefox's config file to open the chain's blockexplorer on launch
sed -i "s/brand/$chain/"     ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/always/never/g" ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1

########################## Start by showing versions
echo "Starting BOOTSTRAP PROCESS, version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:    $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  additions repo tag:	$additions_repo_tag"  | tee -a "$bootstrap_log"
echo "  network:		$network"  | tee -a "$bootstrap_log"
echo "  chain:		$chain"  | tee -a "$bootstrap_log"
echo "  type:			$type1 $type2 $type3"  | tee -a "$bootstrap_log"
echo "  go version:     	1.19.8"  | tee -a "$bootstrap_log"
echo "  geth version:   	1.10.26-stable8" | tee -a "$bootstrap_log"
echo "  ethkey version: 	1.10.26-stable8" | tee -a "$bootstrap_log"
echo   | tee -a "$bootstrap_log"

########################## Hardware Fitness of Purpose steps for the log only
uname -a >> "$bootstrap_log"
timedatectl status >> "$bootstrap_log"
sudo fdisk -l >> "$bootstrap_log"
lsblk >> "$bootstrap_log"
nmcli >> "$bootstrap_log"
echo "                     press ENTER to continue"
read
echo
if [ "$network" = "testnet" ]; then
  scp $chain@$$bootstrap:~/s3volumesync.sh $base > /dev/null 2>&1
fi

########################## SSH config
cp ${HOME}/.ssh/config.template ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/brand/$chain/g"     ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/network/$network/g" ${HOME}/.ssh/config > /dev/null 2>&1


########################## AWS credentials
echo "Creating local AWS configurtion and list S3 as a test ..." | tee -a "$bootstrap_log"
mkdir ${HOME}/.aws > /dev/null 2>&1
scp $chain@$bootstrap:~/credentials.$network ${HOME}/.aws/credentials | tee -a "$bootstrap_log"
ls -l ${HOME}/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
aws s3 ls --profile chain | grep $network | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read

########################## Retrieve github token
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >>  "$bootstrap_log" 
echo $pat | tail -c 5 >> "$bootstrap_log"

########################## If a chain, clone blockfabric-ceremony
if [ "$type1" = "chain" ]; then 
  echo " " | tee -a  "$bootstrap_log"
  echo "*** Preparing for $chain Chain: ***"
  echo "Cloning public Blockfabric-ceremony repo, tag=$ceremony_repo_tag ..."  | tee -a "$bootstrap_log"
  echo
  cd $base
  echo "git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git"  | tee -a "$bootstrap_log"
  git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git | tee -a "$bootstrap_log"
  echo; echo -n "  "
  ls blockfabric-ceremony -d >> "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  ls -la blockfabric-ceremony >> "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read
  echo; echo

## Get ansible and shared .env config files - concat into single file
  echo "Now retrieve the $chain $network chain environment variables file ..."  | tee -a "$bootstrap_log"
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ansible.$chain-$network/main/.env > $base/blockfabric-ceremony/ansible.env
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ceremony-env/2.0.1/shared/$type1.env > $base/blockfabric-ceremony/shared.env
  cat $base/blockfabric-ceremony/ansible.env $base/blockfabric-ceremony/shared.env > $base/blockfabric-ceremony/.env
  
  echo | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  cat  $base/blockfabric-ceremony/ansible.env  | tee -a "$bootstrap_log"
  tail -n 1 $base/blockfabric-ceremony/shared.env  | tee -a "$bootstrap_log"
  echo; echo "    If successful, press ENTER"
  read
  echo; echo
fi 

########################## If bridge, halving, other, then clone multi repo
echo "*** Preparing for $chain $type2 $type3 $type4:***"
if [ "$type2" = "bridge" ]; then 
  cd $base  
  echo "Cloning $type2 $type3 $type4 repo(s), tag=$additions_repo_tag ..."  | tee -a "$bootstrap_log"
  echo
  cd $base
  echo "git clone -b $additions_repo_tag  https://blockfabric-admin:ghp_pat@github.com/NerdCoreSdk/blockfabric-ceremony-additions.git" | tee -a "$bootstrap_log"
  git clone -b $additions_repo_tag https://blockfabric-admin:$pat@github.com/NerdCoreSdk/blockfabric-ceremony-additions.git | tee -a "$bootstrap_log"
  echo; echo -n "  "
  ls blockfabric-ceremony-additions -d >> "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  ls -la blockfabric-ceremony-additions >> "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read

  ## Get .env config file
  echo "Now retrieve the   $type2 $type3 $type4   config/environment variables file ..."  | tee -a "$bootstrap_log"

  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ansible.$chain-$network/main/$network/$type2/.env > $base/blockfabric-ceremony-additions/type.env
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ceremony-env/2.0.1/shared/$type2.env >> $base/blockfabric-ceremony-additions/shared.env
  cat $base/blockfabric-ceremony-additions/type.env $base/blockfabric-ceremony-additions/shared.env > $base/blockfabric-ceremony-additions/.env
    
  echo | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  cat $base/blockfabric-ceremony-additions/type.env  | tee -a "$bootstrap_log"
  tail -n 1 $base/blockfabric-ceremony-additions/shared.env  | tee -a "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read

  ########################## Show gastank's public address and balance for Bridge ceremonies
  echo "https://etherscan.io/address/0xA2747b375982A1DE21FB2A5D0e9DB2e2C1AE0d79"

  ############# Command to verify token owner pk
  scp $chain@$bootstrap:~/verify_tokenowner $base/ceremony-artifacts/ > /dev/null 2>&1

fi

########################## Done
echo "    Done. You are now boot-strapped for $network $chain."  | tee -a "$bootstrap_log"
echo
echo "    Continue with the Ceremony Script." | tee -a "$bootstrap_log"
echo
echo
echo "END OF BOOTSTRAP PROCESS FOR $type1 $type2 $type3 $type4 " | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"

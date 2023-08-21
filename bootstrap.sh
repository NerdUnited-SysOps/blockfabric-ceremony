#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version=1.2.0
ceremony_repo_tag=1.1.4
multi_repo_tag=1.0.6
ceremony_os_version=$(cat ~/version | tail -2)
network=$1
brand=$2
type=$3
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/ceremony.log

clear

########################## Check args
if (( $# < 3 )); then
    echo
    echo "Expected  (1)  network [ mainnet | testnet ] "
    echo "          (2)  brand name"
    echo "          (3)  ceremony type [ chain | bridge | lockup_swap | multisig | timelock ]"
    echo
    exit 1
elif (( $# > 3 )); then
    echo; echo "Too many arguments.  Only the network, brand_name, and type are expected."; echo
    exit 2
fi

########################## Prep Firefox homepage for block explorer
echo
## Modify Firefox's config file to open the brand's blockexplorer on launch
sed -i "s/brand/$brand/"     $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/always/never/g" $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1

########################## Start by showing versions
echo "Starting BOOTSTRAP PROCESS, version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:    $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  multi repo tag: $multi_repo_tag"  | tee -a "$bootstrap_log"
echo "  network:                $network"  | tee -a "$bootstrap_log"
echo "  brand:          $brand"  | tee -a "$bootstrap_log"
echo "  type:                   $type"  | tee -a "$bootstrap_log"
echo "  go version:             1.19.8"  | tee -a "$bootstrap_log"
echo "  geth version:           1.10.26-stable8" | tee -a "$bootstrap_log"
echo "  ethkey version:         1.10.26-stable8" | tee -a "$bootstrap_log"
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
  scp $brand@$$bootstrap:~/s3volumesync.sh . > /dev/null 2>&1
fi

########################## SSH config
cp $HOME/.ssh/config.template $HOME/.ssh/config > /dev/null 2>&1
sed -i "s/brand/$brand/g"     $HOME/.ssh/config > /dev/null 2>&1
sed -i "s/network/$network/g" $HOME/.ssh/config > /dev/null 2>&1

########################## AWS credentials
echo "Creating local AWS configurtion and list S3 as a test ..." | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials | tee -a "$bootstrap_log"
ls -l ~/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
aws s3 ls --profile brand | grep $network | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read

########################## Retrieve github token
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >>  "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"

########################## If a chain, clone blockfabric-ceremony
if [ "$type" = "chain" ]; then
  echo " " | tee -a  "$bootstrap_log"
  echo "Cloning public Blockfabric-ceremony repo, tag $ceremony_repo_tag ..."  | tee -a "$bootstrap_log"
  echo
  cd $HOME
  echo "git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git"  | tee -a "$bootstrap_log"
  git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git | tee -a "$bootstrap_log"
  echo; echo -n "  "
  ls blockfabric-ceremony -d | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  ls -la blockfabric-ceremony | tee -a "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read
  echo; echo

## Get .env config files - concat into single file
  echo "Now retrieve the environment variables file ..."  | tee -a "$bootstrap_log"
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ansible.$brand-$network/main/.env > ${HOME}/blockfabric-ceremony/.env
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ceremony-env/main/shared/$type.env >> ${HOME}/blockfabric-ceremony/.env

  echo | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  head -n9  ${HOME}/blockfabric-ceremony/.env  | tee -a "$bootstrap_log"
  echo; echo "    If successful, press ENTER"
  read
  echo; echo
else
########################## If bridge, multisig or timelock, then clone multi repo
  echo "Cloning multi repo, tag $multi_repo_tag ..."  | tee -a "$bootstrap_log"
  echo
  cd $HOME
  echo "git clone -b $multi_repo_tag  https://blockfabric-admin:ghp_pat@github.com/NerdCoreSdk/zet_multi_sig.git" | tee -a "$bootstrap_log"
  git clone -b $multi_repo_tag https://blockfabric-admin:$pat@github.com/NerdCoreSdk/zet_multi_sig.git | tee -a "$bootstrap_log"
  echo; echo -n "  "
  ls zet_multi_sig -d | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  ls -la zet_multi_sig | tee -a "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read

  ## Get .env config file
  echo "Now retrieve the multi config/environment variables file ..."  | tee -a "$bootstrap_log"

  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ansible.$brand-$network/main/$network/$type/.env > ${HOME}/zet_multi_sig/.env
  curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ceremony-env/main/shared/$type.env >> ${HOME}/zet_multi_sig/.env

  ls -la zet_multi_sig/.env | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  echo | tee -a "$bootstrap_log"
  head -n11 zet_multi_sig/.env  | tee -a "$bootstrap_log"
  echo
  echo "    If successful, press ENTER"
  read

  ########################## Retrieve gastank's public address for Bridge ceremonies
  scp $brand@$bootstrap:~/gastank.url . > /dev/null 2>&1
  echo -n "Gas tank address is: " >> "$bootstrap_log"
  cat ~/gastank.url >> "$boostrap_log"
fi

########################## Done
echo "    Done. You are now boot-strapped for a $type ceremony for $network $brand."  | tee -a "$bootstrap_log"
echo
echo "    Continue with the Ceremony Script." | tee -a "$bootstrap_log"
echo
echo
echo "END OF BOOTSTRAP PROCESS" | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"

#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version=1.1.5
ceremony_repo_tag=1.1.2
ceremony_os_version=$(cat ~/version | tail -2)
network=$1
brand=$2
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/bootstrap.log

########################## Check args
if (( $# < 2 )); then
    echo; echo "Exiting. Expected  (1)  mainnet | testnet  AND  (2) chain_name"; echo
    exit 1
elif (( $# > 2 )); then
    echo; echo "Too many arguments.  Only the network AND chain_name are expected."; echo
    exit 2
fi

########################## Prep Firefox homepage for block explorer
echo
## Modify Firefox's config file to open the brand's blockexplorer on launch
sed -i "s/brand/$brand/"     $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/always/never/g" $HOME/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1

########################## Retrieve gastank's public address for Bridge ceremonies
scp $brand@$bootstrap:~/gastank.url . > /dev/null 2>&1
echo
echo

########################## Start with versions
echo "Sarting BOOTSTRAP script version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:     $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  network: $network"  | tee -a "$bootstrap_log"
echo "  brand:   $brand"  | tee -a "$bootstrap_log"
echo "  go version:     1.19.8"  | tee -a "$bootstrap_log"
echo "  geth version:   1.10.26-stable8" | tee -a "$bootstrap_log"
echo "  ethkey version: 1.10.26-stable8" | tee -a "$bootstrap_log"
echo   | tee -a "$bootstrap_log"

########################## Hardware Fitness of Purpose steps for the log only
uname -a >> "$bootstrap_log" ; echo  >> "$bootstrap_log"
timedatectl status >> "$bootstrap_log"; echo  >> "$bootstrap_log"
sudo fdisk -l >> "$bootstrap_log";  echo >> "$bootstrap_log"
lsblk >> "$bootstrap_log"; echo  >> "$bootstrap_log"
nmcli >> "$bootstrap_log"; echo  >> "$bootstrap_log"
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

########################## Clone blockfabric-ceremony
echo " " | tee -a  "$bootstrap_log"
echo "Cloning public Blockfabric-ceremony repo, tag $ceremony_repo_tag ..."  | tee -a "$bootstrap_log"
echo
cd $HOME
echo "git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git"  | tee -a "$bootstrap_log"
git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git | tee -a "$bootstrap_log"
echo
echo -n "  "
ls blockfabric-ceremony -d | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
ls -la blockfabric-ceremony | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
echo
echo

########################## AWS credentials
echo "Creating local AWS configurtion and list S3 as a test ..." | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials | tee -a "$bootstrap_log"
ls -l ~/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
aws s3 ls --profile chain | grep $network | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read

########################## Get .env config files - concat into single file
echo "Now secure copy the environment variables file ..."  | tee -a "$bootstrap_log"
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >> "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"
curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ansible.$brand-$network/main/.env > ${HOME}/blockfabric-ceremony/.env
curl -s https://blockfabric-admin:$pat@raw.githubusercontent.com/NerdUnited-SysOps/ceremony-env/main/.env >> ${HOME}/blockfabric-ceremony/.env
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
head -n9  ${HOME}/blockfabric-ceremony/.env  | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
echo
echo

########################## Done
echo "    Done. You are now boot-strapped."  | tee -a "$bootstrap_log"
echo
echo "    cd into blockfabric-ceremony/ and run ceremony.sh"
echo
echo
echo "END OF BOOTSTRAP.LOG" >> "$bootstrap_log"

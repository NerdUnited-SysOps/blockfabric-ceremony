#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version=1.0.10.ms
multisig_repo_tag=1.0.3
ceremony_os_version=$(cat ~/version | tail -2)
network=$1
brand=$2
type=$3
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/bootstrap.log


if (( $# < 3 )); then
    echo; echo "Exiting. "
          echo "Expected  (1)  mainnet | testnet "
	  echo "          (2)  brand_name"
	  echo "          (3)  chain | bridge | lockup_swap | multisig"
	  echo
    exit 1
elif (( $# > 3 )); then
    echo; echo "Too many arguments.  Only the network, brand_name, and type are expected."; echo
    exit 2
fi


# execute these commands to get to this bootstrap.sh script:
#  ssh-keygen -q -t ed21559
#  # will prompt for fingerprint and password
#  ssh-copy-id brand@bootstrap_server
#  scp brand@bootstrap_server:bootstrap.multisig.sh .

echo
## Modify Firefox's config file to open the brand's blockexplorer on launch
sed -i "s/brand/$brand/"     /home/user/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" /home/user/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
echo
echo
echo "Sarting BOOTSTRAP script version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  multisig repo tag:	$multisig_repo_tag"  | tee -a "$bootstrap_log"
echo "  network:		$network"  | tee -a "$bootstrap_log"
echo "  brand:		$brand"  | tee -a "$bootstrap_log"
echo "  go version:		1.19.8" | tee -a "$bootstrap_log"
echo "  geth version:		1.10.26-stable8" | tee -a "$bootstrap_log"
echo "  ethkey version:	1.10.26-stable8" | tee -a "$bootstrap_log"

echo   | tee -a "$bootstrap_log"

## Hardware Fitness of Purpose steps for the log only
uname -a >> "$bootstrap_log" ; echo  >> "$bootstrap_log"
timedatectl status >> "$bootstrap_log"; echo  >> "$bootstrap_log"
sudo fdisk -l >> "$bootstrap_log";  echo >> "$bootstrap_log"
lsblk >> "$bootstrap_log"; echo  >> "$bootstrap_log"
nmcli >> "$bootstrap_log"; echo  >> "$bootstrap_log"

echo "                     press ENTER to continue" | tee -a "$bootstrap_log"
read

echo
scp $brand@$genesis:~/s3volumesync.sh . > /dev/null 2>&1
echo " " | tee -a  "$bootstrap_log"
echo
echo
echo "Creating local AWS configurtion and list S3 to verify ..." | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials | tee -a "$bootstrap_log"
ls -l ~/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >> "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"

echo "Cloning Multi_Sig repo, tag $multisig_repo_tag ..."  | tee -a "$bootstrap_log"
echo
cd $HOME
echo "git clone -b $multisig_repo_tag  https://blockfabric-admin:ghp_pat@github.com/NerdCoreSdk/zet_multi_sig.git" | tee -a "$bootstrap_log"
git clone -b $multisig_repo_tag https://blockfabric-admin:$pat@github.com/NerdCoreSdk/zet_multi_sig.git | tee -a "$bootstrap_log"
echo
echo -n "  "
ls zet_multi_sig -d | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
ls -la zet_multi_sig | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
echo "Now secure copy the environment variables file ..."  | tee -a "$bootstrap_log"
git clone https://blockfabric-admin:$pat@github.com/NerdUnited-SysOps/ansible.$brand-$network.git | tee -a "$bootstrap_log"
cp -v ansible.$brand-$network/$network/$type/.env zet_multi_sig/ | tee -a "$bootstrap_log"
ls -la zet_multi_sig/.env | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
head -n11 zet_multi_sig/.env  | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
# Now remove ansible repo. Only the .env file was needed and it's now in zet_multi_sig/
echo "rm -rf ansible.$brand-$network" >> "$bootstrap_log"
rm -rf ansible.$brand-$network
echo
echo
echo
echo "    Done. You are now boot-strapped."  | tee -a "$bootstrap_log"
echo
echo "    Next, mount the USB to identify the CURRENT_OWNER_KEY_PATH" | tee -a "$bootstrap_log"
echo
echo "    cd into zet_multi_sig/ and run ceremony.sh" | tee -a "$bootstrap_log"
echo
echo
echo "END OF BOOTSTRAP.LOG" >> "$bootstrap_log"

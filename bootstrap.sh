#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x


version=1.0.6
ceremony_repo_tag=1.0.10
ceremony_os_version=$(cat ~/version | tail -2)
network=$1
brand=$2
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/bootstrap.log


if (( $# < 2 )); then
    echo; echo "Exiting. Expected  (1)  mainnet | testnet  AND  (2) brand_name"; echo
    exit 1
elif (( $# > 2 )); then
    echo; echo "Too many arguments.  Only the network AND brand_name are expected."; echo
    exit 2
fi


# execute these commands to get to this bootstrap.sh script:
#  ssh-keygen
#  # will prompt for fingerprint and password
#  ssh-copy-id brand@bootstrap_server
#  scp brand@bootstrap_server:bootstrap.sh .

echo
## Modify Firefox's config file to open the brand's blockexplorer on launch
sed -i "s/brand/$brand/"     /home/user/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" /home/user/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
echo
echo
echo "Sarting BOOTSTRAP script version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:     $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  network: $network"  | tee -a "$bootstrap_log"
echo "  brand:   $brand"  | tee -a "$bootstrap_log"
echo   | tee -a "$bootstrap_log"
echo "                     press ENTER to continue"
read
echo
scp $brand@$genesis:~/sha.sh . > /dev/null 2>&1
scp $brand@$genesis:~/s3volumesync.sh . > /dev/null 2>&1
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
echo "Creating local AWS configurtion and list S3 as a test ..." | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials | tee -a "$bootstrap_log"
ls -l ~/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read
echo "Now secure copy the environment variables file ..."  | tee -a "$bootstrap_log"
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >> "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"
git clone https://blockfabric-admin:$pat@github.com/NerdUnited-SysOps/ansible.$brand-$network.git | tee -a "$bootstrap_log"
cp -v ansible.$brand-$network/.env blockfabric-ceremony/ | tee -a "$bootstrap_log"
ls -la blockfabric-ceremony/.env | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
head -n11 blockfabric-ceremony/.env  | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
# Now remove ansible repo. Only the .env file was needed and it's now in  blockfabric-ceremony/
echo "rm -rf ansible.$brand-$network" >> "$bootstrap_log"
rm -rf ansible.$brand-$network
echo
echo
echo
echo "    Done. You are now boot-strapped."  | tee -a "$bootstrap_log"
echo
echo "    cd into blockfabric-ceremony/ and run ceremony.sh"
echo
echo
echo "END OF BOOTSTRAP.LOG" >> "$bootstrap_log"

#!/usr/bin/zsh
# set -x

# introduce credentials to ceremony

## prepare script to prepend contents of bootstrap.log to ceremony.log
cat >combine_logs.sh <<EOF
x=\$(cat ~/bootstrap.log; cat ~/blockfabric-ceremony/ceremony.log)
echo "\$x" > ~/blockfabric-ceremony/ceremony.log.combined
EOF
chmod +x combine_logs.sh

if (( $# < 2 )); then
    echo; echo "Exiting. Expected  (1)  mainnet | testnet  AND  (2) brand_name"; echo
    exit 1
elif (( $# > 2 )); then
    echo; echo "Too many arguments.  Only the network AND brand_name are expected."; echo
    exit 2
fi

os_version=$(cat ~/version | tail -2)
version=1.0.4
network=$1
brand=$2
ceremony_repo_tag=1.0.4
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/bootstrap.log

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
echo "  ceremony OS version: $os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:     $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  network: $network"  | tee -a "$bootstrap_log"
echo "  brand:   $brand"  | tee -a "$bootstrap_log"
echo
echo "                     press ENTER to continue"
read
echo
echo Cloning public Blockfabric-ceremony repo, tag $ceremony_repo_tag ...  | tee -a "$bootstrap_log"
echo
cd $HOME
echo git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git  | tee -a "$bootstrap_log"
git clone -b $ceremony_repo_tag https://github.com/NerdUnited-SysOps/blockfabric-ceremony.git  > /dev/null 2>&1
echo
echo -n "  "
ls blockfabric-ceremony -d
echo
ls -la blockfabric-ceremony
echo
echo "    If successful, press ENTER"
read
echo
echo
echo Creating local AWS configurtion ... | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials
ls -l ~/.aws/
aws s3 ls --profile blockfabric  | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read
echo Now secure copy the environment variables file ...  | tee -a "$bootstrap_log"
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
git clone https://blockfabric-admin:$pat@github.com/NerdUnited-SysOps/ansible.$brand-$network.git > /dev/null 2>&1
cp ansible.$brand-$network/.env blockfabric-ceremony/
ls -la blockfabric-ceremony/.env
head -n 6 blockfabric-ceremony/.env  | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
# Now remove ansible repo. Only the .env file was needed and it's now in  blockfabric-ceremony/
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

#!/usr/bin/zsh
# set -x

# LockuAdmin swap bootstrap: introduce credentials to ceremony


ceremony_os_version=$(cat ~/version | tail -2)
version=1.0.0
network=$1
brand=$2
ceremony_repo_tag=1.0.5
bootstrap=genesis.blockfabric.net
bootstrap_log=${HOME}/bootstrap.swap.log

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
echo "Sarting BOOTSTRAP SWAP script version $version" | tee -a "$bootstrap_log" 
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  ceremony OS version: $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  swap repo tag:     $ceremony_repo_tag"  | tee -a "$bootstrap_log"
echo "  brand:   $brand"  | tee -a "$bootstrap_log" 
echo   | tee -a "$bootstrap_log" 
echo "                     press ENTER to continue"
read
echo
echo " " | tee -a  "$bootstrap_log"
echo "Cloning  NerdCoreSdk/sc_lockup_swap  repo ... " | tee -a "$bootstrap_log"
echo

export GOPRIVATE=github.com/NerdCoreSdk/*
export GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxYIOp
git config --global url."https://${GITHUB_PAT}:x-oauth-basic@github.com/".insteadOf "https://github.com/"

cd $HOME 
echo "git clone https://blockfabric-admin:$GITHUB_PAT@github.com/NerdCoreSdk/sc_lockup_swap.git"   | tee -a "$bootstrap_log"
git clone https://blockfabric-admin:$GITHUB_PAT@github.com/NerdCoreSdk/sc_lockup_swap.git   | tee -a "$bootstrap_log"
echo 

echo -n "  "
ls -l sc_lockup_swap/ | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo
echo "    If successful, press ENTER"
read
echo
echo
echo "Creating local AWS configurtion and list S3 as a test ..." | tee -a "$bootstrap_log"
mkdir $HOME/.aws
scp $brand@$bootstrap:~/credentials.$network $HOME/.aws/credentials | tee -a "$bootstrap_log"
ls -l ~/.aws/ | tee -a "$bootstrap_log"
aws s3 ls --profile {brand_main} | tee -a "$bootstrap_log"
echo
echo
echo "    If successful, press ENTER"
read
echo
echo
echo
cd ~/sc_lockup_swap
git --no-pager reflog show --all | head -n1 | tee -a "$bootstrap_log"
echo "    Done. You are now boot-strapped."  | tee -a "$bootstrap_log"
echo
echo "    cd into sc_lockup_swap/ and run go run main.go" 
echo
echo
echo "END OF BOOTSTRAP.LOG" >> "$bootstrap_log"


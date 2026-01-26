#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version="2.2.3"
chain_repo_tag="2.1.1"
additions_repo_tag="2.7.4"
ansible_repo_tag="main"
ceremonyenv_repo_tag="2.7.4"
ceremony_os_version=$(cat ${HOME}/version | tail -2)
export network=$1
export chain=$2
type=$3
base="${HOME}"
bootstrap=genesis.blockfabric.net
bootstrap_log=$base/ceremony-artifacts/bootstrap.log

cd $base
mkdir -p $base/ceremony-artifacts/
clear

########################## Check args, minimum 3 required
if (( $# < 3 )); then
    echo
    echo "bootstrap.sh ver. $version"
    echo
    echo
    echo "Required: (1)  network     [ mainnet | testnet ] "
    echo "          (2)  chain name  "
    echo "          (3)  additional ceremony types. 1 required, multiple allowed separated by a space "
    echo "               [ admin_fix | binance_bridge | bridge_optionb | chain | halvening | lockup_swap | multisig | reset_decimal | timelock | voting ]"
    echo
    exit 1
fi

##########################  First, reset the bootstrap log file
: > $bootstrap_log

########################## Start by showing arguments and versions
echo "Starting BOOTSTRAP PROCESS, version $version" | tee -a "$bootstrap_log"
echo "  date: $(date)" | tee -a "$bootstrap_log"
echo "  network, chain, type(s):        $@"  | tee -a "$bootstrap_log"
echo "  ceremony OS version:            $ceremony_os_version"  | tee -a "$bootstrap_log"
echo "  ceremony repo tag:              $chain_repo_tag"  | tee -a "$bootstrap_log"
echo "  additions repo tag:             $additions_repo_tag"  | tee -a "$bootstrap_log"
echo "  ansible repo tag:               $ansible_repo_tag"  | tee -a "$bootstrap_log"
echo "  ceremony_env repo tag:          $ceremonyenv_repo_tag"  | tee -a "$bootstrap_log"
echo "  go version:                     1.19.8"  | tee -a "$bootstrap_log"
echo "  geth version:                   1.10.26-stable8" | tee -a "$bootstrap_log"
echo "  ethkey version:                 1.10.26-stable8" | tee -a "$bootstrap_log"
echo   | tee -a "$bootstrap_log"


########################## Prep Firefox homepage for block explorer
echo
## Modify Firefox's config file to open the chain's blockexplorer on launch
sed -i "s/brand/$chain/"     ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/network/$network/" ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1
sed -i "s/always/never/g" ${HOME}/.mozilla/firefox/p8awc088.default-esr/prefs.js > /dev/null 2>&1

########################## Hardware Fitness of Purpose steps for the log only
uname -a >> "$bootstrap_log"
timedatectl status >> "$bootstrap_log"
sudo fdisk -l >> "$bootstrap_log"
lsblk >> "$bootstrap_log"
mount >> "$bootstrap_log"
nmcli >> "$bootstrap_log"
echo "                     press ENTER to continue"
read
echo


########################## SSH config
cp ${HOME}/.ssh/config.template ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/chain/$chain/g"     ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/brand/$chain/g"     ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/network/$network/g" ${HOME}/.ssh/config > /dev/null 2>&1

########################## Other Utility files
scp $chain@$bootstrap:~/clean.sh ${HOME}/ > /dev/null 2>&1

########################## AWS credentials
echo;echo;echo;echo "========== Creating local AWS configurtion and list S3 bucket to verify ==========" | tee -a "$bootstrap_log"
mkdir ${HOME}/.aws > /dev/null 2>&1
scp $chain@$bootstrap:~/credentials.$network.$chain ${HOME}/.aws/credentials | tee -a "$bootstrap_log"
aws s3 ls --profile secrets  | tee -a "$bootstrap_log"
###aws s3 ls --profile chain | grep $network | tee -a "$bootstrap_log"

echo
echo "    If successful, press ENTER"
read

########################## Retrieve github token
pat=$(aws secretsmanager --profile secrets get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >>  "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"


########################  2 functions are used; clone_repos() & get_env_files()
function clone_repos()
{
  clear
  local_type="$1"
  gh_user=""
  echo " " | tee -a  "$bootstrap_log"
  echo;echo;echo;echo "========== Preparing to clone repo for $chain $local_type: =========="

  if [ "$local_type" = "chain" ] || [ "$local_type" = "reset_decimal" ]; then
    gh_enterprise="NerdUnited-SysOps"
    repo="blockfabric-ceremony"
    repo_tag="$chain_repo_tag"
  else
    gh_enterprise="NerdCoreSdk"
    gh_user="blockfabric-ceremony:${pat}@"
    repo="blockfabric-ceremony-additions"
    repo_tag="$additions_repo_tag"
  fi
  repo_dir="$base/$repo"

  echo "Cloning $repo repo with tag:$repo_tag..." | tee -a "$bootstrap_log"
  cd $base
  if [ ! -d $repo_dir ]; then
    ## git -c advice.detachedHead=false checkout <refspec>
    git config --global advice.statusHints false
    git clone --quiet -b $repo_tag https://${gh_user}github.com/$gh_enterprise/$repo.git | tee -a "$bootstrap_log"
    ls $repo -d >> "$bootstrap_log"
    echo | tee -a "$bootstrap_log"
    ls -la $repo >> "$bootstrap_log"
  else
    echo "  -- repo already exists, no need to clone again"
  fi
} ## end of clone function

function get_env_files()   #combine the Type and the Shared .env files into single file
{
  local_type=$1
  gh_enterprise="NerdUnited-SysOps"
  gh_enterprise_env="NerdCoreSDK"
  ansible_repo="ansible.$chain-$network"
  ceremonyenv_repo="blockfabric-ceremony-additions"

  echo;echo;echo;echo "========== Now retrieve the $chain $network $local_type environment variables files =========="  | tee -a "$bootstrap_log"
  curl -s https://blockfabric-ceremony:$pat@raw.githubusercontent.com/$gh_enterprise/$ansible_repo/$ansible_repo_tag/$network/$local_type/.env > $repo_dir/$local_type.env
  cat $repo_dir/$local_type.env | tee -a "$bootstrap_log"

  curl -s https://blockfabric-ceremony:$pat@raw.githubusercontent.com/$gh_enterprise_env/$ceremonyenv_repo/$ceremonyenv_repo_tag/envs/shared/$local_type.env >> $repo_dir/$local_type.env
  tail -n 1 $repo_dir/$local_type.env  | tee -a "$bootstrap_log"
} ## end of env function

######################## Process the various types of ceremonies (arguments)
while test $# -gt 0
do
  type=$3
  repo_dir=
  bridge="no"
  ## $3, $4, $5, etc are the 'types' of ceremonies to run. $1 and $2 are not. The shift at the end will cycle thru the args
  if  [ ! -z "$type" ]; then
    clone_repos $type
    get_env_files $type
    ## types array needed at the end to make multiple bootstrap.log files; 1 per type
    types+=($type)
    echo; echo "    If successful, press ENTER"; read
    echo; echo
  fi

  shift ## move to the next argument
done

###### Add-on utilities
scp $chain@$genesis:~/cplog.sh $base/ > /dev/null 2>&1
scp $chain@$genesis:~/mountusb.sh $base/ > /dev/null 2>&1
scp $chain@$genesis:~/wallets.url $base/ > /dev/null 2>&1
scp $chain@$genesis:~/clean.sh $base/ > /dev/null 2>&1
#######################


echo
echo "=============== END OF BOOTSTRAP PROCESS FOR $network $chain ===============" | tee -a "$bootstrap_log"
echo
if [ -f $base/wallets.url ]; then
  echo "       Check these balance first:" | tee -a "$bootstrap_log"
  cat $base/wallets.url | tee -a "$bootstrap_log"
fi
echo
echo "===============     Continue with the Ceremony Script    ===============" | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"
echo | tee -a "$bootstrap_log"

#########################  Testnet Tools
if [ "$network" != "mainnet" ]; then
  scp -pr $chain@$genesis:~/testnettools $base/testnettools > /dev/null 2>&1
  echo "Run ~/testnettools/labtop_config.sh $network $chain <labtop_port> type(s)"
  echo "see ~/testnettools/labtop.instructions for more lab details"
fi

######################## Create a bootstrap.log file for each "type" of ceremony requested
for type in $types; do
  ## these are the 'types' of ceremonies to run. Each one get its own bootstrap.log copy
    cp $bootstrap_log ~/ceremony-artifacts/"${type}"_bootstrap.log
done

######### end

#!/usr/bin/zsh
# introduce credentials to ceremony

# set -x

version="2.3.5"
chain_repo_tag="2.3.0"
additions_repo_tag="2.9.2"
ansible_repo_tag="main"
ceremonyenv_repo_tag="2.9.2"
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
    echo "               [ admin_fix | binance_bridge | bridge_optionb | bridge_x | chain | halvening | lockup_swap | multisig | reset_decimal | timelock | voting ]"
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
echo
echo "========== Getting ssh config template and utilities ==========" | tee -a "$bootstrap_log"
scp $chain@$bootstrap:~/ssh.config.template ${HOME}/.ssh/config.template > /dev/null 2>&1
cp ${HOME}/.ssh/config.template ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/chain/$chain/g"     ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/brand/$chain/g"     ${HOME}/.ssh/config > /dev/null 2>&1
sed -i "s/network/$network/g" ${HOME}/.ssh/config > /dev/null 2>&1

########################## Other Utility files
scp $chain@$bootstrap:~/clean.sh ${HOME}/ > /dev/null 2>&1

########################## AWS credentials
echo
echo "========== Creating local AWS configuration and verifying S3 bucket ==========" | tee -a "$bootstrap_log"

mkdir -p "${HOME}/.aws"

if ! scp "${chain}@${bootstrap}:~/credentials.${network}.${chain}" "${HOME}/.aws/credentials" | tee -a "$bootstrap_log"; then
    echo "ERROR: Failed to copy AWS credentials from ${bootstrap}" | tee -a "$bootstrap_log"
    exit 1
fi

expected_bucket="${network}-${chain}"

echo "Listing accessible S3 buckets" | tee -a "$bootstrap_log"

bucket_listing="$(aws s3 ls --profile blockfabric 2>&1)"
aws_status=$?

echo "$bucket_listing" | tee -a "$bootstrap_log"

if [ "$aws_status" -ne 0 ]; then
    echo "ERROR: Failed to list S3 buckets using profile 'blockfabric'" | tee -a "$bootstrap_log"
    exit 1
fi

if ! printf '%s\n' "$bucket_listing" | awk '{print $3}' | grep -Fxq "$expected_bucket"; then
    echo "ERROR: Expected S3 bucket '${expected_bucket}' was not found" | tee -a "$bootstrap_log"
    exit 1
fi

echo "Verified: found S3 bucket '${expected_bucket}'" | tee -a "$bootstrap_log"

echo "Listing contents of s3://${expected_bucket}/" | tee -a "$bootstrap_log"

bucket_contents="$(aws s3 ls "s3://${expected_bucket}/" --profile blockfabric 2>&1)"
aws_status=$?

echo "$bucket_contents" | tee -a "$bootstrap_log"

if [ "$aws_status" -ne 0 ]; then
    echo "ERROR: Failed to list contents of s3://${expected_bucket}/" | tee -a "$bootstrap_log"
    exit 1
fi
echo "                     press ENTER to continue"
read
echo

########################## Retrieve github token
pat=$(aws secretsmanager --profile blockfabric get-secret-value --secret-id ceremony_pat --query SecretString --output text)
echo -n " pat is: ..." >>  "$bootstrap_log"
echo $pat | tail -c 5 >> "$bootstrap_log"


########################  3 functions are used; clone_repos(), get_env_files(), & fetch_bridge_x_secrets()
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
    gh_enterprise="NerdUnited-SysOps"
    gh_user="blockfabric-ceremony:${pat}@"
    repo="blockfabric-ceremony-additions"
    repo_tag="$additions_repo_tag"
  fi
  repo_dir="$base/$repo"

  echo "Cloning $repo repo with tag:$repo_tag..." | tee -a "$bootstrap_log"
  cd $base
  if [ ! -d $repo_dir ]; then
    git config --global advice.statusHints false
    git config --global advice.detachedHead false
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
  gh_enterprise_env="NerdUnited-SysOps"
  ansible_repo="ansible.$chain-$network"
  ceremonyenv_repo="blockfabric-ceremony-additions"

  echo;echo;echo;echo "========== Now retrieve the $chain $network $local_type environment variables files =========="  | tee -a "$bootstrap_log"
  curl -s https://blockfabric-ceremony:$pat@raw.githubusercontent.com/$gh_enterprise/$ansible_repo/$ansible_repo_tag/$network/$local_type/.env > $repo_dir/$local_type.env
  cat $repo_dir/$local_type.env | tee -a "$bootstrap_log"

  curl -s https://blockfabric-ceremony:$pat@raw.githubusercontent.com/$gh_enterprise_env/$ceremonyenv_repo/$ceremonyenv_repo_tag/envs/shared/$local_type.env >> $repo_dir/$local_type.env
  tail -n 1 $repo_dir/$local_type.env  | tee -a "$bootstrap_log"
} ## end of env function

######################## bridge_x secrets: fetch all AWS secrets and persist into env file
## This replaces the need to run "Get Secrets" from the bridge_x.sh menu
function fetch_bridge_x_secrets()
{
  local env_file="$repo_dir/bridge_x.env"
  local aws_profile="blockfabric"

  echo;echo;echo;echo "========== Fetching bridge_x secrets from AWS and persisting ==========" | tee -a "$bootstrap_log"

  ## Helper: upsert a variable into the env file
  ## New variables are PREPENDED (not appended) so that downstream
  ## lines like BRIDGE_X_REPO="https://${GITHUB_PAT}@..." see them.
  _upsert_env() {
    local var_name=$1
    local var_val=$2
    local escaped_val=$(echo "${var_val}" | sed 's/[\/&]/\\&/g')

    if grep -q "^export ${var_name}=" "${env_file}"; then
      local tmpfile=$(mktemp)
      sed "s/^export ${var_name}=.*/export ${var_name}=\"${escaped_val}\"/" "${env_file}" > "${tmpfile}"
      mv "${tmpfile}" "${env_file}"
    else
      local tmpfile=$(mktemp)
      echo "export ${var_name}=\"${var_val}\"" > "${tmpfile}"
      cat "${env_file}" >> "${tmpfile}"
      mv "${tmpfile}" "${env_file}"
    fi
    echo "  persisted ${var_name}" | tee -a "$bootstrap_log"
  }

  ## 1) Persist the PAT (already fetched above as $pat)
  _upsert_env "GITHUB_PAT" "${pat}"

  ## 2) Fetch Alchemy API keys
  echo "  fetching alchemy_ethereum_api_key..." | tee -a "$bootstrap_log"
  ALCHEMY_ETHEREUM_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "alchemy_ethereum_api_key" --query SecretString --output text)
  _upsert_env "ALCHEMY_ETHEREUM_API_KEY" "${ALCHEMY_ETHEREUM_API_KEY}"

  echo "  fetching alchemy_bsc_api_key..." | tee -a "$bootstrap_log"
  ALCHEMY_BSC_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "alchemy_bsc_api_key" --query SecretString --output text)
  _upsert_env "ALCHEMY_BSC_API_KEY" "${ALCHEMY_BSC_API_KEY}"

  echo "  fetching alchemy_base_api_key..." | tee -a "$bootstrap_log"
  ALCHEMY_BASE_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "alchemy_base_api_key" --query SecretString --output text)
  _upsert_env "ALCHEMY_BASE_API_KEY" "${ALCHEMY_BASE_API_KEY}"

  ## 3) Fetch Etherscan/scanner API keys
  echo "  fetching etherscan_api_key..." | tee -a "$bootstrap_log"
  ETHERSCAN_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "etherscan_api_key" --query SecretString --output text)
  _upsert_env "ETHERSCAN_API_KEY" "${ETHERSCAN_API_KEY}"

  echo "  fetching bscscan_api_key..." | tee -a "$bootstrap_log"
  BSCSCAN_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "bscscan_api_key" --query SecretString --output text)
  _upsert_env "BSCSCAN_API_KEY" "${BSCSCAN_API_KEY}"

  echo "  fetching basescan_api_key..." | tee -a "$bootstrap_log"
  BASESCAN_API_KEY=$(aws secretsmanager --profile ${aws_profile} get-secret-value --secret-id "basescan_api_key" --query SecretString --output text)
  _upsert_env "BASESCAN_API_KEY" "${BASESCAN_API_KEY}"

  ## 4) Build RPC URLs from the prefix vars already in the env file + the API keys
  ##    The env file has ETH_RPC_PREFIX, BSC_RPC_PREFIX, BASE_RPC_PREFIX from the ansible .env
  source "${env_file}"

  if [[ -n "${ALCHEMY_ETHEREUM_API_KEY}" && -n "${ETH_RPC_PREFIX}" ]]; then
    _upsert_env "ETHEREUM_RPC_URL" "https://${ETH_RPC_PREFIX}.g.alchemy.com/v2/${ALCHEMY_ETHEREUM_API_KEY}"
  fi
  if [[ -n "${ALCHEMY_BSC_API_KEY}" && -n "${BSC_RPC_PREFIX}" ]]; then
    _upsert_env "BSC_RPC_URL" "https://${BSC_RPC_PREFIX}.g.alchemy.com/v2/${ALCHEMY_BSC_API_KEY}"
  fi
  if [[ -n "${ALCHEMY_BASE_API_KEY}" && -n "${BASE_RPC_PREFIX}" ]]; then
    _upsert_env "BASE_RPC_URL" "https://${BASE_RPC_PREFIX}.g.alchemy.com/v2/${ALCHEMY_BASE_API_KEY}"
  fi

  echo | tee -a "$bootstrap_log"
  echo "========== bridge_x secrets fetch complete ==========" | tee -a "$bootstrap_log"
} ## end of fetch_bridge_x_secrets function

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

    ## For bridge_x, also fetch and persist all secrets so the menu can skip "Get Secrets"
    if [ "$type" = "bridge_x" ]; then
      fetch_bridge_x_secrets
    fi

    ## types array needed at the end to make multiple bootstrap.log files; 1 per type
    types+=($type)
    echo; echo "                     press ENTER to continue"; read
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

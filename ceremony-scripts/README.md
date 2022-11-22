# blockfabric-ceremony
This repo facilitates provisioning Nerd brands with their Nerd Chain main net.

# Requirements
* A secure USB drive used to store Ethereum wallet and encrypted private keys generated in ceremony.
* SSH access to clone this repo Github. https://docs.github.com/en/authentication/connecting-to-github-with-ssh
* AWS CLI access to read write to AWS Secrets Manager. - https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html

# Script Dependencies
```
    sudo apt-get install awscli
    sudo apt-get install pwgen
    sudo apt-get install ethereum
    sudo apt-get install jq
    sudo apt-get install golang
    go install github.com/ethereum/go-ethereum/cmd/ethkey@latest
```

# Steps
1. Setup Github SSH Access https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

2. Add your SSH key to your github account. https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?platform=linux

3. Test your SSH connection to GitHub.
```
ssh -T git@github.com
```

4. Clone this repo

5. Run the script
```
./ceremony.sh -d <volume_path_to_move_keys_to> -i <space_delimited_list_of_ips>
```

You will be prompted for an AWS Access Key ID and AWS Access Key during this process.
This is the only info you'll be prompted for.
```
AWS Access Key ID [****************YYVN]: <AWS_ACCESS_KEY_ID>
AWS Secret Access Key [****************h7bq]: <AWS_ACCESS_KEY>
Default region name [us-west-2]: us-west-2
Default output format [json]: json
```

6. Verify results
External volume 
For each IP, there should be a folder with a name correspnding to that ip. i.e. 123.45.67.210 with the following files:
* account_address
* account_ks
* nodekey
* nodekey_address
* nodekey_contents
* nodekey_ks
* nodekey_pub

There should be a folder called lockupOwner with the following files:
* address
* ks
There should be a folder called distributionOwner with the following files:
* address
* ks

Secrets Manager
For every wallet created in the process, there should be a secret with the following:
* Key is the wallet address
* Value is the password used to encrypt that key.

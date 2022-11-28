# Technical Steps

> This document articulates the technical steps to be taken during the ceremony

## Data to bring

> It would be nice to put as much data in Secrets Manager as possible but this
> is where we're at with what will need to be brought in

* Address of the repo to clone (this repo) `git@github.com:NerdUnited-SysOps/blockfabric-ceremony.git`
* AWS Credentials (currently the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`)
* Address of the conductor

### Start script
* Clone this repo
* Provide the script with the following parameters
    * location of each volume
    * brand name

### User Input
* Start the script that will update and grab dependencies
    * During the update we have to select "yes" on the service prompt
    * User inputs credentials to retrieve secure data from AWS Secrets Manager
* The following secrets are retrieved
* Private SSH key for connecting with conductor
* Private SSH key for connecting with nodes
* github keys for smart contracts
* github keys for `ansible-role-lace`

### Update SSH Keys
* generate new ssh keys for conductor and nodes
* Update Conductor and Validator node ssh keys (remove existing entry from authorized hosts)

### Create artifacts
* scp the inventory file from the conductor
* Generate IP addresses from inventory
* Generate the following private keys
    * `nodekey`s for the validators
    * Account keys
    * Distribution Issuer Key
    * Distribution Owner Key
    * Lockup Owner Key
    * Lockup Admin Key
* Generate addresses from the following private keys
    * Accounts
    * Distribution Issuer
    * Distirbution Owner
    * Lockup Owner
* Generate ansible variables
* Generate ansible playbook?

### Execute ansible
* Run ansible against the entire inventory

### Other items
* Need to inactivate the IAM user
* The key will be called blockfabric_<network>_ssh_key_pair
* Need to input brand name for conductor name resolution (the address is `conductor.mainnet.<brand_name>.blockfabric.net`)

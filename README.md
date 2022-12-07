# Blockchain Genesis Ceremony – Technical script 

The objective is to demonstrate as fully as possible that no secrets have been retained. The scripts contained in the repo can be verified prior to the ceremony by anyone with access to the repo. There will be no secret information contained in the repo, it could/should be public. 

## Technical Script 

System Administrator verifies that recording equipment is functioning properly and recording the ceremony. 

Ceremony Administrator identifies the purpose of the meeting and resolve any questions concerning the process (script here). 

Intro by Ceremony Administrator 


## Aegis Secure Key
The Aegis Secure Key is FIPS 140-2 Level 3 certified USB storage device. FIPS 140-2 is a U.S. government computer security standard used to approve cryptographic modules. The device has an internal rechargeable battery with a smart-charging circuit. The manufacturer indicates that the battery should last 3 years in storage. If the battery becomes depleted, the information contained on the device is not compromised, the device requires recharging by USB before attempting to unlock it. The device implements a “Brute Force” defense mechanism. After 3 unsuccessful attempts the device implements a time delay, after 10 attempts the device locks itself, after 20 unsuccessful attempts to unlock all data is cryptographically wiped and rendered unretrievable.  In other words, do not lose your PIN. If you have concerns about this device once you have taken custody of the secrets you may move the information to a device of your choosing. 


<summary><b>Instructions</b></summary>

1. Verify the linux kernel version

```sh
uname -a 
```
2. Verfiy the time and date
```sh
timedatectl (shows local time and ntp status) 
```
3. 
```sh
fdisk -l (shows connected storage devices) 
```
4. 
```sh
ping 1.1.1.1 (verify connectivity) 
```
5. 
```sh
dig Brand website domain name (i.e. google.com) 
```

```sh
./blockchain-ceremony/ceremony.sh
```

## Distribute secrets to custodians
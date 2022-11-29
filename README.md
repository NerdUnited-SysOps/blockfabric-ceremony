# Blockchain Genesis Ceremony – Technical script 


Room will be prepared with audio/video recording equipment and large TV display for everyone in the room to follow along with every command typed on the laptop. 3 laptops will be connected to an ethernet switch with access to the Internet and each computer will be connected to a video switcher allowing for display and recording. Laptops will be numbered 1-3. Laptops are from different suppliers and have internal storage removed. 5 dice on table in plain view. Tamper Evident materials. Apricorn Aegis Secure Keys in original packaging (tamper evident) (how many?). A brand may choose to provide their own laptop to generate the keys. If the brand chooses this option, the machine needs to meet some minimum system requirements provided upon request. 

 



## Physical Security 

Room 

* Not controlled by NU (i.e., hotel suite / conference room) 

* Access based on pre-defined list of attendees 

* Individual outside to check attendee list and grant admission 

* Sign in/out sheet 

* ID checks 

(Un)Authorized devices 
* Mobile Devices 
* tablets 
* “smart” devices 

 

## Assumptions 

Nerd will provide an independent auditor (Casey spoke with Tom about this today, Tom will arrange for a CPA to attend and observe). 

The brand may ask for Nerd Provided participants to submit to a background check but time must be allowed to perform the background check, this will be at the brand’s discretion and expense. 



## Technical Script 

System Administrator verifies that recording equipment is functioning properly and recording the ceremony. 

Ceremony Administrator identifies the purpose of the meeting and resolve any questions concerning the process (script here). 

Intro by Ceremony Administrator 

Why are we here 

Roles of individuals 

Description of environment and controls 

Physical space description 

## Aegis Secure Key
The Aegis Secure Key is FIPS 140-2 Level 3 certified USB storage device. FIPS 140-2 is a U.S. government computer security standard used to approve cryptographic modules. The device has an internal rechargeable battery with a smart-charging circuit. The manufacturer indicates that the battery should last 3 years in storage. If the battery becomes depleted, the information contained on the device is not compromised, the device requires recharging by USB before attempting to unlock it. The device implements a “Brute Force” defense mechanism. After 3 unsuccessful attempts the device implements a time delay, after 10 attempts the device locks itself, after 20 unsuccessful attempts to unlock all data is cryptographically wiped and rendered unretrievable.  In other words, do not lose your PIN. If you have concerns about this device once you have taken custody of the secrets you may move the information to a device of your choosing. 

Physical controls 

Inventory overview 

Selection of equipment (based on die roll) 

Roll call (state name and purpose) 

Agenda 

Fitness for purpose 

Key generation 

Key distribution / assignment 

External Witness (Brand President or designee) chooses one die from within 5 dice on the table. The other dice are moved out of the way to prevent mixing with the chosen die but kept and provided in the package to Ceremony Administrator at the end of the ceremony. The die is rolled to determine which laptop will be used to initialize the blockchain. Attendees in room verify the number rolled. If the number rolled is 1-3 the ceremony continues to next step, if 4-6 the die is re-rolled until a number between 1-3 is presented. 

The System Administrator pushes the Macro button on the video switcher that corresponds to the number rolled (this selects the laptop for display on the TV in the room and creates a split screen for recording). The TV in the room will show a split screen display with camera feed on the left and command window from laptop on the left with a simple background. Above the background should be a clock with the current time with a second indicator (in a future audit the introduction of a time with seconds should help to ensure that the video has not been edited). 

Somehow we need to introduce the removeable media device to the room, simply producing it (pulling it out of a bag seems like slight of hand). 

Removeable media is connected to laptop and laptop is booted 

Somehow we need to show that the OS that is booted is “publicly” available for inspection (suggestion is to host on GitHub and supply the link a week prior to ceremony) 

Laptop will boot a linux distro to a simple window manager (xfce) with a single terminal (fullscreen). ISO should be linked here.

Crypto Operator issues the following Linux command to ensure “Fitness of Purpose” 

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
dig Brand website domain name (i.e. galvan.health) 
```

Ask room for consensus on “fitness of purpose” of equipment 

Crypto Operator issues the following Linux commands 

```sh
git clone repo… (this repo should be “publicly” available (VP of engineering of brand should inspect prior to ceremony, repo should be available X number of days before ceremony) 
```
cd local repo directory 

Execute scripts according to steps in `technical-steps.md`

```
execute script 1 (creates and copies keys to validator nodes) 
```
execute script 2 (copies keys to HOT locations), AWS SM 

execute script n (no keys should be shown on screen during creation), keys can be stored locally on filesystem as it is ephemeral

*** I propose all ansible is executed here to copy keys to VA nodes and start geth systemd service *** 

*** wait some period to verify service status and creation of new blocks *** 

*** Potentially have someone outside room execute test to verify proper blockchain initialization*** How to we communicate outside room, perhaps MS Teams, perhaps with the video split screen shared to participants 

Keys are copied “Trust” 

Its probably time reenforce that if the PIN code is lost or forgotten the data is not accessible (never ever, full stop), we can supply a sticky note and pen if they choose to right it down, they won’t have their phone or other electronic device at this time) thoughts here??? 

“Trust” rep breaks seal on new Aegis Secure Key 

“Trust” creates PIN on new device 

Press “unlock” green button (blue and green glow steadily) 

Press “unlock + 9” (blue solid, green blinking) 

Enter PIN, at least 7 digits then “unlock” 

Re-enter PIN and “unlock” (green led will illuminate for one second then only blue solid, this indicates PIN has been set and device is in admin mode” 

DO NOT press any buttons (or the device will need to be unlocked with the PIN) 

Connect the device to the laptop 

Format the device 

Put Linux format commands here 

Execute script to copy keys for “trust” to device 

Verify that keys are on device 

Maybe ls or something else (don’t cat the file…) 

MAKE SECOND COPY??? If this is wanted rinse and repeat (I don’t know if this is a good idea, its likely the same PIN could be chosen and one lost PIN would result in no access to multiple devices) 

Disconnect device from laptop, return to box with other materials (manual etc.) and put the box in a TE bag 

Serial number of TE bag is noted on the record 

Keys are copied for “Node Governance” 

Rinse and repeat above steps 

Keys for Brand 

Rinse and repeat 

Keys for Blockade 

You know the drill 

Super Admin Key (could we please propose a better name) 

Person 1 places stainless steel plate in laser engraver (I found one that will not require that everyone in the room wear eye protection) and types first 8 words in laser engraver software (different laptop, may introduce confidence problems) 

Starts engrave process 

When the engrave is finished (need to test) person 1 removes the ss plate and places it somewhere (obscured from the camera, maybe face down IDK 

Person two places second plate in engraver and types 8 words 

Same as the first person when engrave finishes 

Person 3 does last 3 words 

Plates are then combined somehow without anyone in the room seeing all 24 words 

Plates are put in a TE bag and serial number noted 

Power off laptop, disconnect removeable media, place the removeable media and the die used in a TE bag, note serial and give it to someone (need name here Daniel probably) 

Gather the chain of custody forms and the paper script used for the ceremony, put it in a bag (maybe the same bag as the removeable media and the die) 

 

The objective is to demonstrate as fully as possible that we have NOT kept secret information . The obvious problem is that we just used a laptop connected to the Internet and copied some keys to some places. Our answer is that we pulled the repo from GitHub with all the scripts and we did not deviate from the process. The scripts contained in the repo can be verified prior to the ceremony by anyone with access to the repo. There will be no secret information contained in the repo, it could/should be public (if we choose). 

 

 

Stuff that still needs in the process somewhere 

Key Custodianship Form, with chain of custody acknowledgment 

Storage Types 

Hot – programmatic (hopefully not Hashi Corp vault) 

Warm – quicker access, stored near HQ, stored on SD card, requires approval to access 

Plan on anonymous storage facility 

Cold 

Switzerland? 

Burn – deleted after creation 

 

 

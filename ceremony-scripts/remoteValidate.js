function chainBalance() {
	accounts = debug.accountRange().accounts
	return Object.keys(accounts).reduce(function(x, acc) {
		return parseInt(accounts[acc].balance) + parseInt(x)
	})
}

function validation(lcAddress, dcAddress, diAddress) {
	accounts = debug.accountRange().accounts
	
	// lockupContractAddress = "0x47e9fbef8c83a1714f1951f142132e6e90f5fa5d"
	lockupContractAddress = lcAddress
	lockupStorage = accounts[lockupContractAddress].storage
	lockupIssuer = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]
	lockupDailyUnlock = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000004"]
	lockupTimestamp = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000005"]

	// distributionContractAddress = "0x8be503bcded90ed42eff31f56199399b2b0154ca"
	distributionContractAddress = dcAddress
	distributionStorage = accounts[distributionContractAddress].storage
	distributionOwner = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000000"]
	distributionIssuer = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000001"]
	distributionLockup = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]

	// distributionIssuerAddress = "0x561913d96dc4317118fe43421242f67128784fba"
	distributionIssuerAddress = diAddress

	template = "" + "\n" +
" Lockup Balance: " + accounts[lockupContractAddress].balance + "\n" +
" Lockup Daily_Unlock: " + parseInt(lockupDailyUnlock,16) + "\n" +
" Lockup_Timestamp: " + parseInt(lockupTimestamp,16) + "\n" +
" Days Since Unlock: " + Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24) + "\n" +
" Current Unlocked: " + (Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24) * parseInt(lockupDailyUnlock,16)) + "\n" +
" Distribution Balance: " + debug.accountRange().accounts[distributionContractAddress].balance + "\n" +
" Distribution Issuer Balance: " + eth.getBalance(distributionIssuerAddress) + "\n" +
" Lockup Distirbution Issuer Balance: " + (parseInt(eth.getBalance(distributionIssuerAddress)) + parseInt(accounts[lockupContractAddress].balance)) + "\n" +
"" + "\n" +
" Total Chain Balance: " + Object.keys(accounts).reduce(function(x, acc){return parseInt(accounts[acc].balance) + parseInt(x)}) + "\n" +
" Total Chain Balance: " + chainBalance() + "\n" +
" " + "\n" +
" Lockup Issuer Address == Distribution Contract: " + (lockupIssuer == distributionContractAddress.substring(2)) + "\n" +
" Distribution Lockup Address == Lockup Contract: " + (distributionLockup == lockupContractAddress.substring(2)) + "\n" +
" DistributionIssuer == DistributionIssuerAddress: " + (distributionIssuer == distributionIssuerAddress.substring(2)) + "\n" +
""
 console.log(template)
// '

	return 'validation'
}
//console.log(name())

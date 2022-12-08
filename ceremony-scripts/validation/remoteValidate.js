function getDistributionIssuerAddress() {
	accounts = debug.accountRange().accounts
	return Object.keys(accounts).filter(function(x) {
		return !accounts[x].hasOwnProperty("storage")
	})[0]
}

function getDistributionIssuerAddress() {
	accounts = debug.accountRange().accounts
	return Object.keys(accounts).filter(function(x) {
		return !accounts[x].hasOwnProperty("storage")
	})[0]
}

function chainBalance() {
	accounts = debug.accountRange().accounts
		return Object.keys(accounts).reduce(function(acc, x) {return acc + parseInt(eth.getBalance(x))
	}, 0)
}

function daysSinceUnlock(lockupTimestamp) {
	return Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24)
}

function currentUnlocked(lockupTimestamp, lockupDailyUnlock) {
	return Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24) * parseInt(lockupDailyUnlock,16)
}

function validation() {
	accounts = debug.accountRange().accounts
	lockupContractAddress = "0x47e9fbef8c83a1714f1951f142132e6e90f5fa5d"
	lockupStorage = accounts[lockupContractAddress].storage
	lockupIssuer = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]
	lockupDailyUnlock = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000004"]
	lockupTimestamp = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000005"]

	distributionContractAddress = "0x8be503bcded90ed42eff31f56199399b2b0154ca"
	distributionStorage = accounts[distributionContractAddress].storage
	distributionOwner = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000000"]
	distributionIssuer = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000001"]
	distributionLockup = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]

	distributionIssuerAddress = getDistributionIssuerAddress()

	template = "" + "\n" +
" Lockup Contract:\t" + lockupContractAddress + "\n" + 
" Distribution Contract:\t" + distributionContractAddress + "\n" + 
" Distribution Issuer:\t" + distributionIssuerAddress + "\n\n" + 

" Distribution Started: " + new Date(parseInt(lockupTimestamp,16) * 1000).toString() + "\n" +
" Days Since Unlock: " + daysSinceUnlock(lockupTimestamp) + "\n\n" +
" Network Version: " + net.version + "\n" +
" Chain ID:\t  " + parseInt(eth.chainId()) + "\n\n" +
" Lockup Balance:\t" + accounts[lockupContractAddress].balance + "\n" +
" Lockup Daily_Unlock:\t   " + parseInt(lockupDailyUnlock,16) + "\n" +
" Current Unlocked:\t" + currentUnlocked(lockupTimestamp, lockupDailyUnlock) + "\n" +
" Distribution Contract:\t\t\t  " + debug.accountRange().accounts[distributionContractAddress].balance + "\n" +
" Distribution Issuer:\t       " + eth.getBalance(distributionIssuerAddress) + "\n\n" +
" Total Chain Balance:\t" + chainBalance() + "\n\n" +
" Lockup Issuer Address == Distribution Contract:  " + (lockupIssuer == distributionContractAddress.substring(2)) + "\n" +
" Distribution Lockup Address == Lockup Contract:  " + (distributionLockup == lockupContractAddress.substring(2)) + "\n" +
" DistributionIssuer == DistributionIssuerAddress: " + (distributionIssuer == distributionIssuerAddress.substring(2)) + "\n" +
""
	console.log(template)

	return 'validation'
}

validation()

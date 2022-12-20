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

function repeat(c, len) {
	item = ''
	for (i = 0; i < len; i++) {
		item += c
	}
	return item
}

function tab(first, second, maxLength) {
	space = maxLength - (first.length + second.length)
	return first + repeat(' ', space) + second
}

function validation() {
	accounts = debug.accountRange().accounts

	rowLength = 66

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

	// Printing

	console.log(repeat('-', rowLength))
	console.log(' Balances')
	console.log(repeat('-', rowLength))
	console.log("")

	console.log(tab(" Lockup Daily Unlock", parseInt(lockupDailyUnlock,16).toString(), rowLength))
	console.log(tab(" Lockup Balance", accounts[lockupContractAddress].balance, rowLength))
	console.log(tab(" Current Unlocked", currentUnlocked(lockupTimestamp, lockupDailyUnlock).toString(), rowLength))
	console.log(tab(" Distribution Contract", debug.accountRange().accounts[distributionContractAddress].balance, rowLength))
	console.log(tab(" Distribution Issuer", eth.getBalance(distributionIssuerAddress).toString(), rowLength))
	console.log("")
	console.log(tab(" Total Chain Balance", chainBalance().toString(), rowLength))

	console.log("")
	console.log(repeat('-', rowLength))
	console.log(' Addresses')
	console.log(repeat('-', rowLength))
	console.log("")

	console.log(tab(" Lockup Contract", lockupContractAddress, rowLength))
	console.log(tab(" Distribution Contract", distributionContractAddress, rowLength))
	console.log(tab(" Distribution Issuer", distributionIssuerAddress, rowLength))

	console.log("")
	console.log(repeat('-', rowLength))
	console.log(' General Metrics')
	console.log(repeat('-', rowLength))
	console.log("")

	console.log(tab(" Distribution Started", new Date(parseInt(lockupTimestamp,16) * 1000).toString(), rowLength))
	console.log(tab(" Days Since Unlock", daysSinceUnlock(lockupTimestamp), rowLength))
	console.log(tab(" Network Version", net.version, rowLength).toString())
	console.log(tab(" Chain ID", parseInt(eth.chainId()).toString(), rowLength))

	console.log("")
	console.log(repeat('-', rowLength))
	console.log(' Contract Routing')
	console.log(repeat('-', rowLength))
	console.log("")
	
	console.log(tab(" Lockup Issuer Address == Distribution Contract", (lockupIssuer == distributionContractAddress.substring(2)).toString(), rowLength))
	console.log(tab(" Distribution Lockup Address == Lockup Contract", (distributionLockup == lockupContractAddress.substring(2)).toString(), rowLength))
	console.log(tab(" DistributionIssuer == DistributionIssuerAddress", (distributionIssuer == distributionIssuerAddress.substring(2)).toString(), rowLength))
	console.log("")

	return 'Validation Complete'
}

validation()

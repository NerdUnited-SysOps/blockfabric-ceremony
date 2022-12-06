function basicValidation() {
	const template = `
	Chain Creation Date: ${parseInt(eth.getBlockByNumber(0).timestamp,16)}
	Network Id: ${net.version}
	Chain Id: ${parseInt(eth.chainId(),16)}
	Gas Price:  ${eth.gasPrice}
	Block Number: ${eth.blockNumber}
	Peer Count: ${net.peerCount}
	`
	console.log(template)
	return 'basic validation'
}

function deeperValidation() {
	const accounts = debug.accountRange()
	console.log('here\'s a test console log')
	return 'test return'
//accounts = debug.accountRange().accounts
// 
// lockupContractAddress = "0x47e9fbef8c83a1714f1951f142132e6e90f5fa5d";
// lockupStorage = accounts[lockupContractAddress].storage
// lockupIssuer = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]
// lockupDailyUnlock = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000004"]
// lockupTimestamp = lockupStorage["0x0000000000000000000000000000000000000000000000000000000000000005"]
// 
// distributionContractAddress = "0x8be503bcded90ed42eff31f56199399b2b0154ca"
// distributionStorage = accounts[distributionContractAddress].storage
// distributionOwner = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000000"]
// distributionIssuer = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000001"]
// distributionLockup = distributionStorage["0x0000000000000000000000000000000000000000000000000000000000000002"]
// 
// distributionIssuerAddress = "0x053db724edd7248168355ec21526c53cce87e921"
// 
// template = "" + \
// " ChainCreationDate:__" + parseInt(eth.getBlockByNumber(0).timestamp,16) + \
// " ChainId:__" + parseInt(eth.chainId(),16) + \
// " NetworkId:__" + net.version + \
// " GasPrice:__" + eth.gasPrice + \
// " Lockup_Balance:__" + accounts[lockupContractAddress].balance + \
// " Lockup_Daily_Unlock:__" + parseInt(lockupDailyUnlock,16) + \
// " Lockup_Timestamp:__" + parseInt(lockupTimestamp,16) + \
// " DaysSinceUnlock:__" + Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24) + \
// " CurrentUnlocked:__" + (Math.floor(((Date.now()/1000) - parseInt(lockupTimestamp,16))/60/60/24) * parseInt(lockupDailyUnlock,16)) + \
// " Distribution_Balance:__" + debug.accountRange().accounts[distributionContractAddress].balance + \
// " Distribution_Issuer_Balance:__" + eth.getBalance(distributionIssuerAddress) + \
// " Lockup+DistirbutionIssuer_Balance:__" + (parseInt(eth.getBalance(distributionIssuerAddress)) + parseInt(accounts[lockupContractAddress].balance)) + \
// "" + \
// " TotalChainBalance:__" + Object.keys(accounts).reduce(function(x, acc){return parseInt(accounts[acc].balance) + parseInt(x)}) + \
// " " + \
// " LockupIssuerAddress==DistributionContract:__" + (lockupIssuer == distributionContractAddress.substring(2)) + \
// " DistributionLockupAddress==LockupContract:__" + (distributionLockup == lockupContractAddress.substring(2)) + \
// " DistributionIssuer==DistributionIssuerAddress:__" + (distributionIssuer == distributionIssuerAddress.substring(2)) + \
// ""
// console.log(template)
// '
}

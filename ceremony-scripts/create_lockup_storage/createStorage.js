const { sha3, soliditySha3, padLeft } = require("web3-utils");
const storageSlot = "0000000000000000000000000000000000000000000000000000000000000001";

const args = process.argv.slice(2)

function createStorage(listOfAddresses) {
    return listOfAddresses.map(address => {
        const paddedAccount = padLeft(address.toLowerCase(), 64)
        const slot = sha3(`0x${paddedAccount}${storageSlot}`).substring(2).toLowerCase();
				return `"0x${slot}": "01",`
    }).join(' ')
}

console.log(createStorage(args))


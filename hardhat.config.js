const { task } = require("hardhat/config");

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("hardhat-contract-sizer");
require("hardhat-erc1820");

task("accounts", "Prints the list of accounts", async () => {
    const accounts = await ethers.getSigners();
    for (const account of accounts) {
        console.log(account.address);
    }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.11"
};
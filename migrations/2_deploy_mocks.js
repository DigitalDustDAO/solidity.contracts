require("@openzeppelin/test-helpers/configure")({
    provider: web3.currentProvider,
    environment: "truffle"
});

const { singletons } = require("@openzeppelin/test-helpers");

const DigitalDustDAOMock = artifacts.require("DigitalDustDAOMock");
const SocialTokenManagerMock = artifacts.require("SocialTokenManagerMock");
const LongTailSocialTokenMock = artifacts.require("LongTailSocialTokenMock");
// const SocialTokenNFTMock = artifacts.require("SocialTokenNFTMock");

module.exports = async function (deployer, network, accounts) {
    const [creator, userA, userB, ...others] = accounts;

    if (network === "test" || network === "development")  {
        console.log("deploying mock contracts...")

        // In a test environment an ERC777 token requires deploying an ERC1820 registry
        await singletons.ERC1820Registry(creator);

        // Initialize the DAO contract
        await deployer.deploy(DigitalDustDAOMock);
        const daoInstance = await DigitalDustDAOMock.deployed(); 
        const daoAddress = daoInstance.address;

        // Add DAO members and create a LTST project
        const daoProjectId = 1000;
        await daoInstance.startProject(
            daoProjectId,
            256,
            web3.utils.asciiToHex("LTST")
        );

        // Initialize the STM using LTST project id
        await deployer.deploy(SocialTokenManagerMock, daoAddress, daoProjectId)
        const stmInstance = await SocialTokenManagerMock.deployed();
        const stmAddress = stmInstance.address;
        console.log("stmAddress:", stmAddress)

        // Initialize LTST using STM
        await deployer.deploy(LongTailSocialTokenMock, stmAddress, []);
        const ltstInstance = await LongTailSocialTokenMock.deployed();
        const ltstAddress = ltstInstance.address;
        console.log("ltstAddress:", ltstAddress)
    }
};

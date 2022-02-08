require("@openzeppelin/test-helpers/configure")({
    provider: web3.currentProvider,
    environment: "truffle"
});

const { singletons } = require("@openzeppelin/test-helpers");

const DigitalDustDAOMock = artifacts.require("DigitalDustDAOMock");
const SocialTokenManagerMock = artifacts.require("SocialTokenManagerMock");
const LongTailSocialTokenMock = artifacts.require("LongTailSocialTokenMock");
const SocialTokenNFTMock = artifacts.require("SocialTokenNFTMock");

module.exports = async function (deployer, network, accounts) {
    const [creator, userA, userB, ...others] = accounts;

    if (network === "test" || network === "development")  {
        console.log("deploying mock contracts...");

        // In a test environment an ERC777 token requires deploying an ERC1820 registry
        await singletons.ERC1820Registry(creator);

        // Initialize the DAO contract
        await deployer.deploy(DigitalDustDAOMock);
        const daoInstance = await DigitalDustDAOMock.deployed(); 

        // Add DAO members and create a LTST project
        const daoProjectId = 1000;
        await daoInstance.startProject(
            daoProjectId,
            256,
            web3.utils.asciiToHex("LTST")
        );

        // Initialize the STM using LTST project id
        await deployer.deploy(SocialTokenManagerMock, daoInstance.address, daoProjectId);
        const stmInstance = await SocialTokenManagerMock.deployed();
        console.log("stmInstance.address:", stmInstance.address);

        // Initialize LTST using STM
        await deployer.deploy(LongTailSocialTokenMock, stmInstance.address, []);
        const ltstInstance = await LongTailSocialTokenMock.deployed();
        console.log("ltstInstance.address:", ltstInstance.address);

        // Initialize NFT
        await deployer.deploy(SocialTokenNFTMock, stmInstance.address, "", "");
        const nftInstance = await SocialTokenNFTMock.deployed();
        console.log("nftInstance.address:", nftInstance.address);

        // Re-initialize STM using NFT+LTST
        stmInstance.initialize(ltstInstance.address, nftInstance.address)
    }
};

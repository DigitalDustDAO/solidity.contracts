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
    const [creator, userA, userB, userC, ...others] = accounts;

    if (network === "test" || network === "development")  {
        console.log("deploying mock contracts...");

        // In a test environment an ERC777 token requires deploying an ERC1820 registry
        await singletons.ERC1820Registry(creator);

        // Initialize the DAO contract
        await deployer.deploy(DigitalDustDAOMock);
        const daoInstance = await DigitalDustDAOMock.deployed();

        // Create a LTST project in the DAO
        const daoProjectId = 1000;
        await daoInstance.startProject(
            daoProjectId,
            256,
            web3.utils.asciiToHex("LTST")
        );

        // Add userA,B,C to the LTST project
        await daoInstance.setRights(daoProjectId, userA, 500);
        await daoInstance.setRights(daoProjectId, userB, 200);
        await daoInstance.setRights(daoProjectId, userC, 100);

        // Initialize the STM using LTST projectId
        await deployer.deploy(SocialTokenManagerMock, daoInstance.address, daoProjectId);
        const stmInstance = await SocialTokenManagerMock.deployed();

        // Initialize LTST using STM
        await deployer.deploy(LongTailSocialTokenMock, stmInstance.address, []);
        const ltstInstance = await LongTailSocialTokenMock.deployed();

        // Initialize NFT
        await deployer.deploy(SocialTokenNFTMock, stmInstance.address, "", "");
        const nftInstance = await SocialTokenNFTMock.deployed();

        // Re-initialize STM using NFT+LTST
        await stmInstance.initialize(ltstInstance.address, nftInstance.address);
    }
};

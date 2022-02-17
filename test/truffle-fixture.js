const { singletons } = require("@openzeppelin/test-helpers");

const DigitalDustDAOMock = artifacts.require("DigitalDustDAOMock");
const SocialTokenManagerMock = artifacts.require("SocialTokenManagerMock");
const LongTailSocialTokenMock = artifacts.require("LongTailSocialTokenMock");
const SocialTokenNFTMock = artifacts.require("SocialTokenNFTMock");

module.exports = async (deployer) => {
    console.log('Deploying test fixtures..')

    const [creator, userA, userB, userC, ...others] = await web3.eth.getAccounts();
    console.log('creator:', creator)

    // In a test environment an ERC777 token requires deploying an ERC1820 registry
    await singletons.ERC1820Registry(creator);

    // Initialize the DAO contract
    const dao = await DigitalDustDAOMock.new();
    DigitalDustDAOMock.setAsDeployed(dao);
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
    const stm = await SocialTokenManagerMock.new(daoInstance.address, daoProjectId);
    SocialTokenManagerMock.setAsDeployed(stm);
    const stmInstance = await SocialTokenManagerMock.deployed();

    // Initialize LTST using STM
    const ltst = await LongTailSocialTokenMock.new(stmInstance.address, []);
    await LongTailSocialTokenMock.setAsDeployed(ltst);
    const ltstInstance = await LongTailSocialTokenMock.deployed();

    // Initialize NFT
    const nft = await SocialTokenNFTMock.new(stmInstance.address);
    await SocialTokenNFTMock.setAsDeployed(nft);
    const nftInstance = await SocialTokenNFTMock.deployed();

    // Re-initialize STM using NFT+LTST
    await stmInstance.initialize(ltstInstance.address, nftInstance.address);
};
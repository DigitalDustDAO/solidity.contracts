require('@openzeppelin/test-helpers/configure')({
    provider: web3.currentProvider,
    environment: 'truffle'
});

const { singletons } = require('@openzeppelin/test-helpers');

const DigitalDustDAO = artifacts.require("DigitalDustDAO");
const SocialTokenManager = artifacts.require("SocialTokenManager");
const SocialTokenNFT = artifacts.require("SocialTokenNFT");
const LongTailSocialToken = artifacts.require("LongTailSocialToken");

module.exports = async function (deployer, network, accounts) {
    const [creator, userA, userB, ...others] = accounts;

    if (network === 'test' || network === 'development')  {
        // In a test environment an ERC777 token requires deploying an ERC1820 registry
        await singletons.ERC1820Registry(creator);
    }

    // Initialize the DAO contract
    await deployer.deploy(DigitalDustDAO);
    const daoInstance = await DigitalDustDAO.deployed();
    const daoAddress = daoInstance.address;

    // Add DAO members and create a LTST project
    const daoProjectId = 1000;
    await daoInstance.startProject(
        daoProjectId,
        256,
        web3.utils.asciiToHex("LTST")
    );

    // Initialize the STM using LTST project id
    await deployer.deploy(SocialTokenManager, daoAddress, daoProjectId)
    const stmInstance = await SocialTokenManager.deployed();
    const stmAddress = stmInstance.address;

    // Initialize LTST
    // await deployer.deploy(LongTailSocialToken, stmAddress, []);
    // const ltstInstance = await LongTailSocialToken.deployed();
    // const ltstAddress = ltstInstance.address;
};

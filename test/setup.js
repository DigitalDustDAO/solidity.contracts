const deployBaseMocks = async () => {
    const [creator, userA, userB, userC, ...others] = await ethers.getSigners();

    const DigitalDustDAOMock = await ethers.getContractFactory("DigitalDustDAOMock");
    const BootstrapManagerMock = await ethers.getContractFactory("BootstrapManagerMock");
    const LongTailSocialTokenMock = await ethers.getContractFactory("LongTailSocialTokenMock");
    const SocialTokenNFTMock = await ethers.getContractFactory("SocialTokenNFTMock");


    // Initialize the DAO contract
    const DAO = await DigitalDustDAOMock.deploy();
    await DAO.deployed();

    // Create a LTST project in the DAO
    const daoProjectId = 1000;
    await DAO.startProject(
        daoProjectId,
        256,
        web3.utils.asciiToHex("LTST")
    );

    // Creator adds users [A,B,C] to the LTST project
    await DAO.setRights(daoProjectId, userA.address, 500);
    await DAO.setRights(daoProjectId, userB.address, 200);
    await DAO.setRights(daoProjectId, userC.address, 100);

    // Initialize the BSM using LTST projectId
    const BSTM = await BootstrapManagerMock.deploy(DAO.address, daoProjectId);
    await BSTM.deployed();

    // Initialize LTST using STM
    const LTST = await LongTailSocialTokenMock.deploy(BSTM.address, []);
    await LTST.deployed();

    // Initialize NFT
    const NFT = await SocialTokenNFTMock.deploy(BSTM.address);
    await NFT.deployed();

    // Re-initialize BSM using NFT+LTST
    // await BSTM.initialize(LTST.address, NFT.address);

    return {
        DAO,
        BSTM,
        LTST,
        NFT
    };
};

module.exports = {
    deployBaseMocks
};

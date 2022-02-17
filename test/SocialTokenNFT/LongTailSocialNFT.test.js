const { expect } = require("chai");
require("@nomiclabs/hardhat-waffle");
const { deployBaseMocks } = require('../setup');

describe('LongTailSocialNFT', () => {
    let DAO, BSTM, LTST, NFT;
    let creator, userA, userB, userC, others;

    before(async () => {
        ({ DAO, BSTM, LTST, NFT, daoProjectId } = await deployBaseMocks());

        [creator, userA, userB, userC, userD, ...others] = await ethers.getSigners();
    });

    describe('constructor', () => {
        it('Should set the manager address', async () => {
            const SocialTokenNFTMock = await ethers.getContractFactory("SocialTokenNFTMock");
            const newNft = await SocialTokenNFTMock.deploy(BSTM.address);
            await newNft.deployed();

            const manager = await newNft.getManager();
            expect(manager).to.equal(BSTM.address);
        });

        // no visibility on interestBonuses[]
    });

    describe('supportsInterface', () => {
        it('Should return true for ISocialTokenNFT', async () => {
            const nftInterfaceId = await NFT.getInterfaceId();
            await NFT.assertSupportsInterface(nftInterfaceId);
        });

        it('Should return false for other interface ids', async () => {
            const managerInterfaceId = await BSTM.getInterfaceId();
            await expect(
                NFT.assertSupportsInterface(managerInterfaceId)
            ).to.be.reverted;
        });
    });

    describe('setManager', () => {
        let newManager;
        before(async () => {
            const NewBSTM = await ethers.getContractFactory("BootstrapManagerMock");
            newManager = await NewBSTM.deploy(DAO.address, daoProjectId);
            await newManager.deployed();
        });

        it('Should reject request from creator', () => {
            LTST.connect(creator).setManager(LTST.address, true)
        });

        it('Should update the manager address', async () => {

        });
    });

    describe.skip('setInterestBonus', () => {});
    describe.skip('setForgeValues', () => {});
    describe.skip('setBaseURI', () => {});
    describe.skip('setGroupSizes', () => {});
    describe.skip('resizeElementLibarary', () => {});
    describe.skip('awardBounty', () => {});
    describe.skip('interestBonus', () => {});
    describe.skip('tokenURI', () => {});
    describe.skip('getGroupSizes', () => {});
    describe.skip('getClaimableBountyCount', () => {});
    describe.skip('collectBounties', () => {});
    describe.skip('forgeElement', () => {});
    describe.skip('forge', () => {});
    describe.skip('getGroupSizes', () => {});
    describe.skip('getGroupSizes', () => {});
    describe.skip('getGroupSizes', () => {});
});

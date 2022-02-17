const { expect } = require("chai");
require("@nomiclabs/hardhat-waffle");
const { deployBaseMocks } = require('../setup');

describe('Bootstrapper', (accounts) => {
    let DAO, BSTM, STNFT;
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const tokenAddress = '0x0000000000000000000000000000000000000123';
    const nftAddress = '0x0000000000000000000000000000000000000321';
    const daoProjectId = 1000;
    let creator, userA, userB, userC, others;
    const RIGHTS = {
        none: 0,
        grant: 100,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        ({ DAO, BSTM, LTST, NFT } = await deployBaseMocks());

        [creator, userA, userB, userC, userD, ...others] = await ethers.getSigners();
    });

    describe('supportsInterface', () => {
        it('Should approve ISocialTokenManager', async () => {
            // TODO: learn how to build ISocialTokenManager interface outside of solidity
            const iSocialTokenInterfaceId = await BSTM.getInterfaceId();
            const response = await BSTM.supportsInterface(iSocialTokenInterfaceId);
            expect(response).to.equal(true);
        });

        it('Should reject other hashes', async () => {
            const response = await BSTM.supportsInterface('0x01234567');
            expect(response).to.equal(false);
        });
    });

    describe('initialize', () => {
        it('Should reject an unexpected token interface', async () => {
            // expecting LTST, NFT
            await expect(
                BSTM.connect(creator).initialize(DAO.address, DAO.address)
            ).to.be.revertedWith('Invalid interface');
        });

        it('Should reject userC (too little access)', async () => {
            await expect(
                BSTM.connect(userC).initialize(LTST.address, NFT.address)
            ).to.be.revertedWith('Not authorized');
        });

        it('Should accept valid contract interfaces', async () => {
            await BSTM.connect(creator).initialize(LTST.address, NFT.address);
        });
    });

    describe('authorize', () => {
        // TODO: find a way to get ISocialTokenManager.Sensitivity
        const sensitivity = {
            'Basic': 0,
            'Council': 1,
            'Maintainance': 2,
            'Elder': 3,
            'TokenContract': 4,
            'NFTContract': 5,
            'Manager': 6,
        };

        it('Should authorize creator w/ Basic', async () => {
            await BSTM
                .authorize(
                    creator.address,
                    sensitivity.Basic
                );
        });

        it('Should authorize creator w/ Council', async () => {
            await BSTM
                .authorize(
                    creator.address,
                    sensitivity.Council
                );
        });

        it('Should authorize creator w/ Maintainance', async () => {
            await BSTM
                .authorize(
                    creator.address,
                    sensitivity.Maintainance
                );
        });

        it('Should authorize creator w/ Elder', async () => {
            await BSTM
                .authorize(
                    creator.address,
                    sensitivity.Elder
                );
        });

        it.skip('Should authorize creator w/ Manager', async () => {
            await BSTM
                .authorize(
                    creator.address,
                    sensitivity.Manager
                );
        });

        it('Should reject unauthorized users', async () => {
            await expect(
                BSTM.authorize(userD.address, 12345)
            ).to.be.reverted;
        });

        it('Should authorize NFT contract w/ NFTContract', async () => {
            await BSTM
                .authorize(
                    NFT.address,
                    sensitivity.NFTContract
                );
        });

        it('Should reject DAO w/ NFTContract', async () => {
            await expect(
                BSTM.authorize(DAO.address, sensitivity.NFTContract)
            ).to.be.reverted;
        });

        it('Should authorize LTST w/ TokenContract', async () => {
            await BSTM
                .authorize(
                    LTST.address,
                    sensitivity.TokenContract
                );
        });

        it('Should reject DAO w/ TokenContract', async () => {
            await expect(
                BSTM.authorize(DAO.address, sensitivity.TokenContract)
            ).to.be.reverted;
        });
    });

    describe('deprecateSelf', () => {});

    describe('getDaoContract', () => {
        it('Should return the DAO contract address', async () => {
            const daoAddress = await BSTM.getDaoContract();
            expect(daoAddress).to.equal(DAO.address);
        });
    });

    describe('getTokenContract', () => {
        it('Should return the LTST contract address', async () => {
            const tokenAddress = await BSTM.getTokenContract();
            expect(tokenAddress).to.equal(LTST.address);
        });
    });

    describe('getNftContract', () => {
        it('Should return the NFT contract address', async () => {
            const nftAddress = await BSTM.getNftContract();
            expect(nftAddress).to.equal(NFT.address);
        });
    });

    describe.skip('adjustInterest', () => {});

    describe('upgrade', () => {
        it('Should reject insufficient authorization', async () => {
            await expect(
                BSTM.connect(userC).upgrade(BSTM.address, creator.address)
            ).to.be.reverted;
        });

        it('Should reject contracts that dont implement ISocialTokenManager', async () => {
            await expect(
                BSTM.connect(userC).upgrade(LTST.address, creator.address)
            ).to.be.reverted;
        });

        it('Should allow creator to upgrade the contract', async () => {
            await BSTM
                .connect(creator)
                .upgrade(
                    BSTM.address,
                    creator.address
                );
        });
    });
});
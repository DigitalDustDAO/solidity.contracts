const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const DigitalDustDAO = artifacts.require('DigitalDustDAO');
const SocialTokenManager = artifacts.require('SocialTokenManager');
const ISocialTokenManager = artifacts.require('ISocialTokenManager');

contract('SocialTokenManager', (accounts) => {
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const tokenAddress = '0x0000000000000000000000000000000000000123';
    const nftAddress = '0x0000000000000000000000000000000000000321';
    const daoProjectId = 1000;
    let DAO, STM, STNFT;
    const [creator, userA, userB, ...others] = accounts;
    const RIGHTS = {
        none: 0,
        grant: 100,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        DAO = await DigitalDustDAO.deployed();
        STM = await SocialTokenManager.deployed();
        STNFT = await SocialTokenNFT.deployed();
    });

    describe('supportsInterface', () => {
        it('Should approve ISocialTokenManager', async () => {
            // TODO: learn how to build ISocialTokenManager interface outside of solidity
            const iSocialTokenInterfaceId = await STM.getInterfaceId();
            const response = await STM.supportsInterface(iSocialTokenInterfaceId);
            expect(response).to.equal(true);
        });

        it('Should reject other hashes', async () => {
            const response = await STM.supportsInterface('0x01234567');
            expect(response).to.equal(false);
        });
    });

    contract('initialize', () => {
        it('Should reject an unexpected token interface', async () => {
            const daoAddress = DAO.address;
            // await STM.initialize(daoAddress, daoAddress, { from: creator });
            await expectRevert(
                STM.initialize(daoAddress, daoAddress, { from: creator }),
                'Invalid interface'
            );
        });

        it.skip('Should accept a token that supports ISocialToken', async () => {
            // TODO: initialize SocialToken address (LTST)
            // TODO: initialize SocialTokenNFT address (LTST_NFT)
        });
    });

    describe('authorize', () => {
        describe.skip('(source, target, level)', () => {
            let authorize, sensitivity;
            before(() => {
                authorize = STM?.methods['authorize(address,address,uint8)'];
            });
        });

        describe('(source, level)', () => {
            let authorize, sensitivity;
            before(() => {
                authorize = STM?.methods['authorize(address,uint8)'];
                sensitivity = ISocialTokenManager.Sensitivity;
            });

            it('Should authorize creator w/ Elder', async () => {
                await authorize(creator, sensitivity.Elder, { from: creator });
            });

            it('Should reject creator w/ invalid level', async () => {
                await expectRevert(
                    authorize(creator, 12345, { from: creator }),
                    'value out-of-bounds'
                );
            });
    
            it('Should reject userA w/ Basic', async () => {
                await expectRevert(
                    authorize(userA, sensitivity.Basic, { from: userA }),
                    'Not authorized'
                );
            });
        });
    });

    describe('deprecateSelf', () => {});

    describe('getDaoContract', () => {});
    describe('getTokenContract', () => {});
    describe('getNftContract', () => {});
    describe('adjustInterest', () => {});
});
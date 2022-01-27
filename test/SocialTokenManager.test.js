const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const DigitalDustDAO = artifacts.require('DigitalDustDAO');
const SocialTokenManager = artifacts.require('SocialTokenManager');

contract('SocialTokenManager', (accounts) => {
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const tokenAddress = '0x0000000000000000000000000000000000000123';
    const nftAddress = '0x0000000000000000000000000000000000000321';
    const daoId = 101;
    let daoAddress, STM;
    const interfaceHash = '0x89dc2bfa'
    const [creator, userA, userB, ...others] = accounts;
    const RIGHTS = {
        none: 0,
        grant: 100,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        // initialize the DAO
        const DAO = await DigitalDustDAO.new({ from: creator });
        daoAddress = DAO.address;
        await DAO.startProject(1, 1000, "0x0000", { from: creator });

        // initial the STM
        STM = await SocialTokenManager.new(DAO.address, daoId, { from: creator });
    });

    describe('constructor', () => {
        it('Should set dao to input address', async () => {
            expect(await STM.dao.call()).to.equal(daoAddress);
        });

        it('Should set token address to zero address', async () => {
            expect(await STM.token.call()).to.equal(zeroAddress);
        });
    });

    describe('supportsInterface', () => {
        it('Should approve ISocialTokenManager', async () => {
            const response = await STM.supportsInterface(interfaceHash);
            expect(response).to.equal(true);
        });

        it('Should reject other hashes', async () => {
            const response = await STM.supportsInterface('0x01234567');
            expect(response).to.equal(false);
        });
    });

    describe('setTokenManager', () => {
        it('Uses onlyOwner', async () => {
            await expectRevert(
                STM.setTokenManager(nftAddress, { from: userA }),
                'Not enough rights to update'
            );
        });

        it('Uses hasToken', async () => {
            await expectRevert(
                STM.setTokenManager(nftAddress, { from: creator }),
                'Must set token first'
            );
        });

        // TODO: validate setTokenManager called token.setManager (via event?)
    });

    describe('setNFT', () => {
        it('Uses onlyOwner', async () => {
            await expectRevert(
                STM.setNFT(nftAddress, { from: userA }),
                'Not enough rights to update'
            );
        });

        it('Uses hasToken', async () => {
            await expectRevert(
                STM.setNFT(nftAddress, { from: creator }),
                'Must set token first'
            );
        });

        // TODO: validate setNFT called token.setNFT (via event?)
    });

    describe('setToken', () => {
        it('Applies onlyOwner', async () => {
            await expectRevert(
                STM.setToken(tokenAddress, { from: userA }),
                'Not enough rights to update'
            );
        });

        it('Defaults to a zero address', async () => {
            expect(await STM.token.call()).to.equal(zeroAddress);
        });

        it('setToken updates the token address', async () => {
            await STM.setToken(tokenAddress, { from: creator });
            expect(await STM.token.call()).to.equal(tokenAddress);
        });
    });
});
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const DigitalDustDAO = artifacts.require('DigitalDustDAO');
const SocialTokenManager = artifacts.require('SocialTokenManager');
const ISocialTokenManager = artifacts.require('ISocialTokenManager');
const LongTailSocialToken = artifacts.require('LongTailSocialToken');

contract.skip('LongTailSocialToken', (accounts) => {
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    const tokenAddress = '0x0000000000000000000000000000000000000123';
    const nftAddress = '0x0000000000000000000000000000000000000321';
    const daoProjectId = 1000;
    let DAO, STM;
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
        LTST = await LongTailSocialToken.deployed();
    });

    it('initializes LTST', async () => {
        expectEvent(LTST).to.be.defined;
    });
});
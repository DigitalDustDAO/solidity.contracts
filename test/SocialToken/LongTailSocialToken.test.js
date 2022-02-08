const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const DigitalDustDAOMock = artifacts.require('DigitalDustDAOMock');
const SocialTokenManagerMock = artifacts.require('SocialTokenManagerMock');
const ISocialTokenManager = artifacts.require('ISocialTokenManager');
const LongTailSocialTokenMock = artifacts.require('LongTailSocialTokenMock');

contract('LongTailSocialToken', (accounts) => {
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
        DAO = await DigitalDustDAOMock.deployed();
        STM = await SocialTokenManagerMock.deployed();
        LTST = await LongTailSocialTokenMock.deployed();
    });

    
    describe('constructor', () => {
        it('sets the manager address', async () => {
            const managerAddress = await LTST.getManager();
            expect(managerAddress).to.equal(STM.address);
        });

        it('sets lastInterestAdjustment to uint64.max', async () => {
            const lastInterestAdjustment = await LTST.getLastInterestAdjustment();
            const maxUint64 = '18446744073709551615';  // 2**64 - 1
            expect(lastInterestAdjustment.toString()).to.equal(maxUint64);
        });

        describe('Should set initial rates', () => {
            let baseInterestRate,
                linearInterestBonus,
                quadraticInterestBonus,
                rewardPerMiningTask,
                miningGasReserve;

            before(async () => {
                const rates = await LTST.getContractInterestRates();
                ([
                    baseInterestRate,
                    linearInterestBonus,
                    quadraticInterestBonus,
                    rewardPerMiningTask,
                    miningGasReserve
                ] = Object.values(rates).map(n => n.toNumber()));
            });

            it('Should set baseInterestRate', () => {
                expect(baseInterestRate).to.equal(50);
            });

            it('Should set linearInterestBonus', () => {
                expect(linearInterestBonus).to.equal(25);
            });

            it('Should set quadraticInterestBonus', () => {
                expect(quadraticInterestBonus).to.equal(10);
            });

            it('Should set rewardPerMiningTask', () => {
                expect(rewardPerMiningTask).to.equal(50);
            });

            it('Should set miningGasReserve', () => {
                expect(miningGasReserve).to.equal(1500);
            });
        });
    });

    describe.only('setManager', () => {
        it('Should deny access from userA', async () => {
            await expectRevert.unspecified(
                LTST.setManager(zeroAddress, true, { from: userA })
            );
        });

        it('Should deny access from creator', async () => {
            await expectRevert.unspecified(
                LTST.setManager(zeroAddress, true, { from: creator })
            );
        });

        it('Should allow access from manager contract', async () => {
            const newManager = await SocialTokenManagerMock.new(DAO.address, 9999, { from: creator });
            await LTST.setMsgSender(STM.address)
            await LTST.setManager(newManager.address, true);
            expect(await LTST.getManager()).to.equal(newManager.address);
        });
    });

    describe('setInterestRates', () => {});
    describe('stake', () => {});
    describe('unstake', () => {});
    describe.skip('mine', () => {});
    describe('forge', () => {});
    describe('getNumMiningTasks', () => {});
    describe('getContractInterestRates', () => {});
    describe('getStakeValues', () => {});
    describe('getCurrentDay', () => {});
    describe('getVotingPower', () => {});
    describe('calculateInterest', () => {});
    describe('_votingWeight', () => {});
    describe('_fullInterest', () => {});
    describe('calculateInterestRate', () => {});
    describe('transfer', () => {});
    describe('send', () => {});
});
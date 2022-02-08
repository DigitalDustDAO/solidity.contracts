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
    const [creator, userA, userB, userC, ...others] = accounts;
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

    contract('setManager', () => {
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
            await LTST.setMsgSender(STM.address);
            await LTST.setManager(newManager.address, true);
            expect(await LTST.getManager()).to.equal(newManager.address);
        });
    });

    contract('setInterestRates', () => {
        it('Should reject updates from userC', async () => {
            const newRates = [5, 10, 15, 20, 25];
            await expectRevert.unspecified(
                LTST.setInterestRates(...newRates, { from: userC })
            );
        });

        it('Should update values from creator', async () => {
            const newRates = [10, 20, 30, 40, 50];
            await LTST.setInterestRates(...newRates, { from: creator });

            const updatedRates = await LTST.getContractInterestRates()
                .then(ratesObj => Object.values(ratesObj).map(n => n.toNumber()));
            
            for(let i = 0; i < newRates.length; i++) {
                expect(updatedRates[i]).to.equal(newRates[i]);
            };
        });
    });

    contract.only('stake', () => {
        const [minAmount, minDays, maxDays] = [10**11, 30, 5844];

        before(async () => {
            await LTST.setBalance(creator, 5 * minAmount);
            await LTST.setBalance(userB, minAmount);

            const balanceOfCreator = await LTST.balanceOf(creator, { from: creator })
                .then(n => n.toNumber());
            expect(balanceOfCreator).to.equal(5 * minAmount);

            const balanceOfUserB = await LTST.balanceOf(userB, { from: userB })
                .then(n => n.toNumber());
            expect(balanceOfUserB).to.equal(minAmount);

            const balanceOfUserC = await LTST.balanceOf(userC, { from: userC })
                .then(n => n.toNumber());
            expect(balanceOfUserC).to.equal(0);
        });

        it('Should stake the minimum amount and duration for creator', async () => {
            await LTST.stake(minAmount + 1, minDays + 1, { from: creator });
        });

        it('Should reject insufficient stake amount', async () => {
            await expectRevert.unspecified(
                LTST.stake(minAmount - 1, minDays, { from: creator })
            );
        });

        it('Should reject insufficient duration', async () => {
            await expectRevert.unspecified(
                LTST.stake(minAmount, minDays - 1, { from: creator })
            );
        });
    });

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

    contract.only('calculateInterestRate', () => {
        const expectedRates = {
            30: 9800,
            45: 21425,
            60: 37550,
            75: 58175,
            90: 83300,
        };

        Object.entries(expectedRates).map(([days, expectedRate]) => {
            it(`Should return rate for ${days} days`, () => {
                return LTST.calculateInterestRate(creator, days)
                    .then(response => {
                        const actualRate = response.toNumber();
                        expect(actualRate).to.equal(expectedRate);
                    });
            });
        });
    });

    describe('transfer', () => {});
    describe('send', () => {});
});
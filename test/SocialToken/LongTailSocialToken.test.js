const { expect } = require("chai");
require("@nomiclabs/hardhat-waffle");
const { deployBaseMocks } = require('../setup');

describe('LongTailSocialToken', () => {
    let BSTM, LTST;
    const zeroAddress = '0x0000000000000000000000000000000000000000';
    let creator, userA, userB, userC, others;

    before(async () => {
        ({ DAO, BSTM, LTST, NFT } = await deployBaseMocks());

        [creator, userA, userB, userC, userD, ...others] = await ethers.getSigners();
    });

    describe('constructor', () => {
        it('sets the manager address', async () => {
            const managerAddress = await LTST.getManager();
            expect(managerAddress).to.equal(BSTM.address);
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

    describe('setManager', () => {
        after(async () => {
            await LTST.setMsgSender(zeroAddress);
        });

        it('Should deny access from userA', async () => {
            await expect(
                LTST.connect(userA).setManager(zeroAddress, true)
            ).to.be.reverted;
        });

        it('Should deny access from creator', async () => {
            await expect(
                LTST.connect(creator).setManager(zeroAddress, true)
            ).to.be.reverted;
        });

        it('Should reject invalid contract type', async () => {
            // connect doesn't work for contract-to-contract calls
            await LTST.setMsgSender(BSTM.address);

            await expect(
                LTST.connect(creator).setManager(LTST.address, true)
            ).to.be.reverted;
        });

        it('Should allow access from manager contract', async () => {
            // connect doesn't work for contract-to-contract calls
            await LTST.setMsgSender(BSTM.address);
            await LTST.setManager(BSTM.address, true);

            expect(await LTST.getManager()).to.equal(BSTM.address);
        });
    });

    describe('setInterestRates', () => {
        it('Should reject updates from userC', async () => {
            const newRates = [5, 10, 15, 20, 25];
            await expect(
                LTST.connect(userC).setInterestRates(...newRates)
            ).to.be.reverted;
        });

        it('Should update values from creator', async () => {
            const newRates = [10, 20, 30, 40, 50];
            await LTST.connect(creator).setInterestRates(...newRates);

            const updatedRates = await LTST.getContractInterestRates();
            for(let i = 0; i < newRates.length; i++) {
                expect(updatedRates[i]).to.equal(newRates[i]);
            };
        });
    });

    describe('stake', () => {
        const [minAmount, minDays, maxDays] = [10**11, 30, 5844];

        before(async () => {
            // Use mock to mint some tokens for creator, userA
            await LTST.mint(userA.address, 5 * minAmount);
            await LTST.mint(userB.address, minAmount);

            await LTST.balanceOf(userA.address)
                .then(balance => {
                    expect(balance).to.equal(5 * minAmount);
                });

            await LTST.balanceOf(userB.address)
                .then(balance => {
                    expect(balance).to.equal(minAmount);
                });
        });

        it('Should stake the minimum amount and duration for creator', async () => {
            const amount = minAmount;
            const numberOfDays = minDays;
            await expect(
                LTST.connect(creator).stake(amount, numberOfDays)
            ).to.emit(LTST, 'Staked').withArgs(
                creator.address,
                numberOfDays,
                numberOfDays + 7,
                amount,
                27610,
                0
            );
        });

        it('Should stake a larger amount and duration', async () => {
            const amount = minAmount * 3;
            const numberOfDays = minDays * 3;
            await expect(
                LTST.connect(creator).stake(amount, numberOfDays)
            ).to.emit(LTST, 'Staked').withArgs(
                creator.address,
                numberOfDays,
                numberOfDays + 7,
                amount,
                244810,
                1
            );
        });

        it('Should reject insufficient stake amount', async () => {
            await expect(
                LTST.connect(creator).stake(minAmount - 1, minDays)
            ).to.be.reverted;
        });

        it('Should reject insufficient balance', async () => {
            await expect(
                LTST.connect(userC).stake(minAmount, minDays)
            ).to.be.reverted;
        });

        it('Should reject insufficient duration', async () => {
            await expect(
                LTST.connect(userC).stake(minAmount, minDays - 1)
            ).to.be.reverted;
        });

        it('Should reject excessive duration', async () => {
            await expect(
                LTST.connect(creator).stake(minAmount, maxDays + 1)
            ).to.be.reverted;
        });
    });

    describe('unstake', () => {
        it('Should unstake a valid stake', async () => {
            await expect(
                LTST.connect(creator).unstake(1)
            ).to.emit(LTST, 'RedeemedStake');
        });

        it('Should revert an invalid (or unstaked) stake id', async () => {
            await expect(
                LTST.connect(creator).unstake(1)
            ).to.be.reverted;
        });
    });

    describe.skip('mine', () => {});
    describe.skip('forge', () => {});
    describe.skip('getNumMiningTasks', () => {});
    describe.skip('getContractInterestRates', () => {});

    describe('getStakeValues', () => {
        it('Returns a valid stake', async () => {
            const [
                start, end, interestRate, principal
            ] = await LTST.getStakeValues(creator.address, 0);

            expect(start).to.equal(7);
            expect(end).to.equal(37);
            expect(interestRate).to.equal(27610);
            expect(principal).to.equal(100000000000);
        });

        it('Reverts on an invalid stakeId', async () => {
            await expect(
                LTST.connect(userA).getStakeValues(creator.address, 5)
            ).to.be.reverted;
        });
    });

    describe.skip('getCurrentDay', () => {});
    describe.skip('getVotingPower', () => {});
    describe.skip('calculateInterest', () => {});
    describe.skip('_votingWeight', () => {});
    describe.skip('_fullInterest', () => {});

    describe('calculateInterestRate', () => {
        const expectedRates = {
            30: 27610,
            45: 61660,
            60: 109210,
            75: 170260,
            90: 244810,
        };

        Object.entries(expectedRates).map(([days, expectedRate]) => {
            it(`Should return rate for ${days} days`, () => {
                return LTST.calculateInterestRate(creator.address, days)
                    .then(actualRate => {
                        expect(actualRate).to.equal(expectedRate);
                    });
            });
        });
    });

    describe('transfer', () => {
        it('Creator should transfer tokens to userA', async () => {
            const transferAmount = 1000;
            const initialBalance = await LTST.balanceOf(userA.address).then(n => n.toNumber());
            await LTST.transfer(userA.address, transferAmount);
            const finalBalance = await LTST.balanceOf(userA.address).then(n => n.toNumber());
            expect(finalBalance).to.equal(initialBalance + transferAmount);
        });
    });

    describe('send', () => {
        it('Creator should send tokens to userA', async () => {
            const transferAmount = 1000;
            const initialBalance = await LTST.balanceOf(userA.address).then(n => n.toNumber());
            await LTST.send(userA.address, transferAmount, "0x00");
            const finalBalance = await LTST.balanceOf(userA.address).then(n => n.toNumber());
            expect(finalBalance).to.equal(initialBalance + transferAmount);
        });
    });
});

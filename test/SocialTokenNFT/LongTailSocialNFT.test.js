const { expect } = require("chai");
require("@nomiclabs/hardhat-waffle");
const { deployBaseMocks } = require('../setup');

describe('LongTailSocialNFT', () => {
    let DAO, BSTM, LTST, NFT;
    let creator, userA, userB, userC, others;
    let tokenIds = {};
    let tokenIndices = [];

    before(async () => {
        ({ DAO, BSTM, LTST, NFT, daoProjectId, zeroAddress } = await deployBaseMocks());

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

        it('Should resolve ISocialTokenNFT', async () => {
            const nftInterfaceId = await NFT.getInterfaceId();
            await NFT.supportsInterface(nftInterfaceId);
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

        after(async () => {
            await NFT.setMsgSender(newManager.address);
            await NFT.setManager(BSTM.address);
            await NFT.setMsgSender(zeroAddress);
        });

        it('Should reject request from creator', async () => {
            await expect(
                NFT.connect(creator).setManager(LTST.address)
            ).to.be.reverted;
        });

        it('Should update the manager address', async () => {
            await NFT.setMsgSender(BSTM.address);
            await NFT.setManager(newManager.address);
            expect(await NFT.getManager()).to.equal(newManager.address);
        });
    });

    describe('setInterestBonus', () => {
        for(let level = 0; level < 8; level++) {
            it(`Should set level ${level}`, async () => {
                await NFT.setInterestBonus(level, level * 2);
            });
        };

        it('Should allow creator to setInterestBonus', async () => {
            await NFT.connect(creator).setInterestBonus(5, 10);
        });

        it('Should reject userB for insufficient authorization', async () => {
            await expect(
                NFT.connect(userB).setInterestBonus(5, 10)
            ).to.be.reverted;
        });

        it('Should reject level 8+', async () => {
            await expect(
                NFT.setInterestBonus(8, 20)
            ).to.be.reverted;
        });


    });

    describe('setForgeValues', () => {
        const newValues = [10000, 4, 3, 2];

        it('Should require Sensitivity.Maintenance', async () => {
            await expect(
                NFT.connect(userB).setForgeValues(...newValues)
            ).to.be.reverted;
        });

        it('Should update forge values', async () => {
            await NFT.setForgeValues(...newValues);
            const values = await NFT.getForgeValues();
            values.forEach((v, i) => {
                expect(v).to.equal(newValues[i]);
            })
        });
    });

    describe('setBaseURI', () => {
        const newURI = 'www.myCoolUrl.com/';
        it('Should allow creator to setBaseURI', async () => {
            await NFT.setBaseURI(newURI);
            expect(await NFT.getBaseURI()).to.equal(newURI);
        });

        it('Should require Sensitivity.Maintenance', async () => {
            await expect(
                NFT.connect(userB).setBaseURI('foo')
            ).to.be.reverted;
        });
    });

    describe('getGroupSizes', () => {
        it('Should return default sizes for group 0', async () => {
            const groupSizes = await NFT.getGroupSizes(0);

            // NFTs are not grouped until level 1, so getGroupSizes only return 7 values
            expect(groupSizes.length).to.equal(7);
            groupSizes.forEach(size => {
                expect(size).to.equal(0);
            });
        });
    });

    describe('setGroupSizes', () => {
        it('Should set sizes for group 1', async () => {
            await NFT.setGroupSizes(1, [10,11,12]);

            const groupSizes = await NFT.getGroupSizes(1);
            expect(groupSizes.length).to.equal(7);
            expect(groupSizes[0]).to.equal(10);
            expect(groupSizes[1]).to.equal(11);
            expect(groupSizes[2]).to.equal(12);
            expect(groupSizes[3]).to.equal(0);
        });
    });

    describe('resizeElementLibarary', () => {
        it('Should create an element library', async () => {
            await NFT.resizeElementLibarary(1000);
        });
    });

    describe('forgeElements', () => {
        before(async () => {
            // creator sends some LTST to userA
            await LTST.send(userA.address, 1000, '0x00');
        });

        const expectBalance = async (expectedBalance, addr = creator.address) => {
            const currentBalance = await NFT.balanceOf(addr);
            expect(currentBalance).to.equal(expectedBalance);
        };

        it('Creator should begin with a zero balance', async () => {
            await expectBalance(0);
            expect(tokenIds[creator.address]).to.equal(undefined);
        });

        it('Should forge 1 new element for creator', async () => {
            await NFT.forgeElement().then(updateTokenIds);
            await expectBalance(1);
            expect(tokenIds[creator.address]?.length).to.equal(1);
        });

        it('Should forge 99 more elements for creator', async () => {
            const numElements = 99;
            await NFT.forgeElements(numElements).then(updateTokenIds);
            await expectBalance(numElements + 1);
            expect(tokenIds[creator.address]?.length).to.equal(numElements + 1);
        });

        it('Should forge 25 elements for userA', async () => {
            const numElements = 25;
            await NFT.connect(userA).forgeElements(numElements).then(updateTokenIds);
            await expectBalance(numElements, userA.address, );
            expect(tokenIds[userA.address]?.length).to.equal(numElements);
        });
    });

    describe('forge', () => {
        it('Should forge three level (0) into a level (1)', async () => {
            const numIntialTokens = tokenIds[creator.address]?.length;
            const [templateId, material1, material2] = tokenIds[creator.address].slice(1, 4);
            await NFT.forge(templateId, material1, material2).then(updateTokenIds);
            // creator should have burned 3, and minted 1 token
            expect(tokenIds[creator.address]?.length).to.equal(numIntialTokens - 2);
        });

        it('Should reject forging elements of different levels', async () => {
            // the last token should now be level 1
            const [templateId, material1, material2] = tokenIds[creator.address].slice(-3);
            await expect(
                NFT.forge(templateId, material1, material2).then(updateTokenIds)
            ).to.be.reverted;
        });

        it('Should reject forging elements from different owners', async () => {
            const templateId = tokenIds[userA.address][0];
            const [material1, material2] = tokenIds[creator.address].slice(0, 1);
            await expect(
                NFT.forge(templateId, material1, material2).then(updateTokenIds)
            ).to.be.reverted;
        });

        it('Should mint several level (1) tokens', async () => {
            for(let i=0; i<20; i++) {
                const [templateId, material1, material2] = tokenIds[creator.address].slice(1, 4);
                await NFT.forge(templateId, material1, material2).then(updateTokenIds);
            }
        });

        it('Should mint several level (2) tokens', async () => {
            for(let i=0; i<4; i++) {
                const [templateId, material1, material2] = tokenIds[creator.address].slice(-7, -4);
                await NFT.forge(templateId, material1, material2).then(updateTokenIds);
            }
        });

        it('Should mint a level (3) token', async () => {
            const [templateId, material1, material2] = tokenIds[creator.address].slice(-4, -1);
            await NFT.forge(templateId, material1, material2).then(updateTokenIds);
        });
    });

    describe('getTokenInfo', () => {
        it('Should return info about a level 0 token', async () => {
            const { level, group, index } = await NFT.getTokenInfo(0);
            expect(level.toNumber()).to.equal(0);
            expect(group.toNumber()).to.equal(0);
            expect(index.toNumber()).to.equal(0);
            tokenIndices[0] = 0;
        });

        it('Should return info about a level 1 token', async () => {
            const { level, group, index } = await NFT.getTokenInfo(125);
            expect(level.toNumber()).to.equal(1);
            expect(group.toNumber()).to.equal(1);
            expect(index.toNumber()).to.equal(0);
            tokenIndices[1] = 125;
        });

        it('Should return info about a level 2 token', async () => {
            const { level, group, index } = await NFT.getTokenInfo(149);
            expect(level.toNumber()).to.equal(2);
            expect(group.toNumber()).to.equal(1);
            expect(index.toNumber()).to.equal(3);
            tokenIndices[2] = 149;
        });

        it('Should return info about a level 3 token', async () => {
            const { level, group, index } = await NFT.getTokenInfo(150);
            expect(level.toNumber()).to.equal(3);
            expect(group.toNumber()).to.equal(1);
            expect(index.toNumber()).to.equal(0);
            tokenIndices[3] = 150;
        });
    });

    describe.skip('awardBounty', () => {});
    describe.skip('interestBonus', () => {});

    describe('tokenURI', () => {
        for(let i=0; i<=3; i++) {
            it(`Should return a tokenURI for level ${i}`, async () => {
                const tokenId = tokenIndices[i];
                const { level, group, index } = await NFT.getTokenInfo(tokenId);

                // make sure our expected indices match up
                expect(level).to.equal(i);

                const tokenURI = await NFT.tokenURI(tokenId);
                expect(tokenURI).to.equal(`www.myCoolUrl.com/${level}/${group}/${index}`);
            });
        }
    });

    describe.skip('getClaimableBountyCount', () => {});
    describe.skip('collectBounties', () => {});

    // keep track of who has which tokenIds
    const updateTokenIds = async (tx) => {
        const receipt = await tx.wait();

        receipt
            ?.events
            ?.filter(i => i?.event === 'Transfer')
            ?.map(({ args: { to, from, tokenId: tokenIdBig } }) => {
                tokenId = tokenIdBig.toNumber();

                const fromIndex = tokenIds[from]?.indexOf(tokenId);
                if (fromIndex >= 0) {
                    tokenIds[from].splice(fromIndex, 1);
                }

                // initialize the to address, if necessary
                if (tokenIds[to]) {
                    tokenIds[to].push(tokenId)
                } else {
                    tokenIds[to] = [tokenId];
                }
            });
    }
});

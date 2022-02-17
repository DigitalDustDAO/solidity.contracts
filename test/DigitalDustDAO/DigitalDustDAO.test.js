const { expect } = require("chai");
require("@nomiclabs/hardhat-waffle");

describe('DigitalDustDAO', () => {
    let dao, creator, userA, userB, others;
    const maxUint32 = 2**32-1;
    const zeroAddress = `0x${'0'.repeat(40)}`;
    const RIGHTS = {
        none: 0,
        grant: 200,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        [creator, userA, userB, userC, ...others] = await ethers.getSigners()
        const DigitalDustDAOMock = await ethers.getContractFactory("DigitalDustDAOMock");
        dao = await DigitalDustDAOMock.deploy();
        await dao.deployed();
    });

    describe('rightsOf', () => {
        it('Constructor should assign rights to creator', async () => {
            const response = await dao.rightsOf(0, creator.address);
            expect(response).to.equal(maxUint32);
        });
    
        it('should not contain rights for userA', async () => {
            const response = await dao.rightsOf(0, userA.address);
            expect(response).to.equal(RIGHTS.none);
        });
    });

    describe.skip('penaltyOf', () => {});
    describe.skip('accessOf', () => {});
    describe.skip('setPenalty', () => {});

    describe('setRights', () => {
        it('userA should not be allowed to increase their own rights', async () => {
            await expect(
                dao.connect(userA).setRights(0, userA.address, RIGHTS.revoke)
            ).to.be.revertedWith('Not enough rights to grant rights');
        });
    
        it('userA should not be allowed to grant rights to userB', async () => {
            await expect(
                dao.connect(userA).setRights(0, userB.address, RIGHTS.grant)
            ).to.be.revertedWith('Not enough rights to grant rights');
        });
    
        it('creator should grant rights to userA, and emit SetRights', async () => {
            await expect(
                dao.connect(creator).setRights(0, userA.address, RIGHTS.revoke)
            ).to.emit(dao, 'SetRights').withArgs(
                0,
                creator.address,
                userA.address,
                RIGHTS.revoke
            );

            const newRights = await dao.rightsOf(0, userA.address);
            expect(newRights).to.equal(RIGHTS.revoke);
        });
    
        it('userA should grant rights to userB and emit SetRights', async () => {
            await expect(
                dao.connect(userA).setRights(0, userB.address, RIGHTS.grant)
            ).to.emit(dao, 'SetRights').withArgs(
                0,
                userA.address,
                userB.address,
                RIGHTS.grant
            );

            const newRights = await dao.rightsOf(0, userB.address);
            expect(newRights).to.equal(RIGHTS.grant);
        });
    
        it('userB should not be allowed to grant more rights than they have', async () => {
            await expect(
                dao.connect(userB).setRights(0, userC.address, RIGHTS.revoke)
            ).to.be.revertedWith('Callers rights cannot exceed granted rights');
        });
    
        it('userB should not be allowed to revoke rights', async () => {
            await expect(
                dao.connect(userB).setRights(0, userA.address, RIGHTS.grant)
            ).to.be.revertedWith('Not enough rights to revoke rights');
        });
    
        it('userA should be able to revoke rights from userB', async () => {
            await expect(
                dao.connect(userA).setRights(0, userB.address, RIGHTS.none)
            ).to.emit(dao, 'SetRights').withArgs(
                0,
                userA.address,
                userB.address,
                RIGHTS.none
            );

            const currentRights = await dao.rightsOf(0, userB.address);
            expect(currentRights).to.equal(RIGHTS.none);
        });
    
        it('userA should not be allowed to revoke rights from someone with higher rights', async () => {
            await expect(
                dao.connect(userA).setRights(0, creator.address, RIGHTS.grant)
            ).to.be.revertedWith('Cannot revoke rights from higher ranked accounts');
        });
    });

    describe('startProject', () => {
        const projectId = 1;
        const projectAmount = 1000;
        const data = '0x00';

        it('creator can start a project and emit StartProject', async () => {
            await expect(
                dao.connect(creator).startProject(projectId, projectAmount, data)
            )
            .to.emit(dao, 'StartProject').withArgs(
                creator.address,
                projectId,
                projectAmount
            )
            .to.emit(dao, 'TransferSingle').withArgs(
                creator.address,
                zeroAddress,
                creator.address,
                projectId,
                projectAmount
            )
        });

        it('startProject should revert if the projectId already exists', async () => {
            await expect(
                dao.connect(creator).startProject(projectId, projectAmount, data)
            ).to.be.revertedWith('Project id already exists');
        });

        it('userA should not be allowed to start a project', async () => {
            await expect(
                dao.connect(userA).startProject(projectId + 1, projectAmount, data)
            ).to.be.revertedWith('Not enough rights');
        });
    });
});
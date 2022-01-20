const { expectRevert } = require('@openzeppelin/test-helpers');
const DigitalDustDAO = artifacts.require("DigitalDustDAO");

contract('DigitalDustDAO', accounts => {
    let instance;
    const [creator, userA, userB, ...others] = accounts;
    const RIGHTS = {
        none: 0,
        grant: 100,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        instance = await DigitalDustDAO.deployed();
    });

    it('should assign rights to creator', async () => {
        const currentRights = await instance.rightsOf(0, creator);
        expect(currentRights.toNumber()).to.equal(1000);
    });

    it('should not contain rights for userA', async () => {
        const currentRights = await instance.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.none);
    });

    it('userA should not be allowed to increase their own rights', async () => {
        await expectRevert(
            instance.setRights(0, userA, RIGHTS.revoke, { from: userA }),
            'Not enough rights to grant rights'
        );
    });

    it('userA should not be allowed to grant rights to userB', async () => {
        await expectRevert(
            instance.setRights(0, userB, RIGHTS.grant, { from: userA }),
            'Not enough rights to grant rights'
        );
    });

    it('creator should grant rights to userA', async () => {
        await instance.setRights(0, userA, RIGHTS.grant);
        const currentRights = await instance.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.grant);
    });

    it('userA should have grant rights', async () => {
        const currentRights = await instance.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.grant);
    });

    it('userA should grant rights to userB', async () => {
        await instance.setRights(0, userB, RIGHTS.grant, { from: userA });
        const currentRights = await instance.rightsOf(0, userB);
        expect(currentRights.toNumber()).to.equal(RIGHTS.grant);
    });

    it('userA should not be allowed to grant more rights than they have', async () => {
        await expectRevert(
            instance.setRights(0, userB, RIGHTS.revoke, { from: userA }),
            'Callers rights cannot exceed granted rights'
        );
    });

    it('userA should not be allowed to revoke rights', async () => {
        await expectRevert(
            instance.setRights(0, userB, RIGHTS.grant, { from: userA }),
            'Not enough rights to revoke rights'
        );
    });

    it('creator should grant revoke rights to userA', async () => {
        await instance.setRights(0, userA, RIGHTS.revoke, { from: creator });
        const currentRights = await instance.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.revoke);
    });

    it('userA should be able to revoke rights from userB', async () => {
        await instance.setRights(0, userB, RIGHTS.none, { from: userA });
        const currentRights = await instance.rightsOf(0, userB);
        expect(currentRights.toNumber()).to.equal(RIGHTS.none);
    });

    it('userA should not be allowed to revoke rights from someone with higher rights', async () => {
        await expectRevert(
            instance.setRights(0, creator, RIGHTS.none, { from: userA }),
            'Caller cannot revoke rights from elevated member'
        );
    });
});
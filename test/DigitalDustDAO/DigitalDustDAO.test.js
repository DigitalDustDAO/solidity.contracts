const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

const DigitalDustDAO = artifacts.require("DigitalDustDAO");

contract('DigitalDustDAO', (accounts) => {
    let contract;
    const [creator, userA, userB, ...others] = accounts;
    const RIGHTS = {
        none: 0,
        grant: 200,
        penalty: 400,
        revoke: 400,
        start: 500
    };

    before(async () => {
        contract = await DigitalDustDAO.new({ from: creator });
    });

    it('Constructor should assign rights to creator', async () => {
        const response = await contract.rightsOf(0, creator);
        expect(response.toNumber()).to.equal(1000);
    });

    it.skip('should emit SetRights', async () => {
        await expectEvent.inConstruction(contract, 'SetRights', {
            id: new BN(0),
            from: new BN(0),
            to: creator,
            rights: new BN(1000)
        });
    });

    it('should not contain rights for userA', async () => {
        const response = await contract.rightsOf(0, userA);
        expect(response.toNumber()).to.equal(RIGHTS.none);
    });

    it('userA should not be allowed to increase their own rights', async () => {
        await expectRevert(
            contract.setRights(0, userA, RIGHTS.revoke, { from: userA }),
            'Not enough rights to grant rights'
        );
    });

    it('userA should not be allowed to grant rights to userB', async () => {
        await expectRevert(
            contract.setRights(0, userB, RIGHTS.grant, { from: userA }),
            'Not enough rights to grant rights'
        );
    });

    it('creator should grant rights to userA, and emit SetRights', async () => {
        const receipt = await contract.setRights(0, userA, RIGHTS.grant);

        const initialRights = await contract.rightsOf(0, userA);
        expect(initialRights.toNumber()).to.equal(RIGHTS.grant);

        expectEvent(receipt, 'SetRights', {
            id: new BN(0),
            from: creator,
            to: userA,
            rights: new BN(RIGHTS.grant)
        });

        const currentRights = await contract.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.grant);
    });

    it('userA should grant rights to userB and emit SetRights', async () => {
        const receipt = await contract.setRights(0, userB, RIGHTS.grant, { from: userA });

        expectEvent(receipt, 'SetRights', {
            id: new BN(0),
            from: userA,
            to: userB,
            rights: new BN(RIGHTS.grant)
        });

        const currentRights = await contract.rightsOf(0, userB);
        expect(currentRights.toNumber()).to.equal(RIGHTS.grant);
    });

    it('userA should not be allowed to grant more rights than they have', async () => {
        await expectRevert(
            contract.setRights(0, userB, RIGHTS.revoke, { from: userA }),
            'Callers rights cannot exceed granted rights'
        );
    });

    it('userA should not be allowed to revoke rights', async () => {
        await expectRevert(
            contract.setRights(0, userB, RIGHTS.grant, { from: userA }),
            'Not enough rights to revoke rights'
        );
    });

    it('creator should grant revoke rights to userA', async () => {
        const receipt = await contract.setRights(0, userA, RIGHTS.revoke, { from: creator });

        const currentRights = await contract.rightsOf(0, userA);
        expect(currentRights.toNumber()).to.equal(RIGHTS.revoke);

        expectEvent(receipt, 'SetRights', {
            id: new BN(0),
            from: creator,
            to: userA,
            rights: new BN(RIGHTS.revoke)
        });
    });

    it('userA should be able to revoke rights from userB', async () => {
        const receipt = await contract.setRights(0, userB, RIGHTS.none, { from: userA });

        const currentRights = await contract.rightsOf(0, userB);
        expect(currentRights.toNumber()).to.equal(RIGHTS.none);

        expectEvent(receipt, 'SetRights', {
            id: new BN(0),
            from: userA,
            to: userB,
            rights: new BN(RIGHTS.none)
        });
    });

    it('userA should not be allowed to revoke rights from someone with higher rights', async () => {
        await expectRevert(
            contract.setRights(0, creator, RIGHTS.none, { from: userA }),
            'Cannot revoke rights from higher ranked accounts'
        );
    });
});
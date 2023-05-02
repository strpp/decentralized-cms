const SwarmAd = artifacts.require("SwarmAd");
const Governor = artifacts.require("SwarmAdGovernor");
const SWRP = artifacts.require("SwarmAdReputationPoints");
const SWCT = artifacts.require("SwarmAdCommunityToken");
const Rewarder = artifacts.require("SwarmAdRewarder");

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert,
    time, // Assertions for transactions that should fail
  } = require('../node_modules/@openzeppelin/test-helpers');

contract("Testing Governance", (accounts) => {

    let SwarmAdContract, GovernorContract, SWCTContract, RewarderContract, SWRPContract;
    let alice = accounts[1];
    let bob = accounts[2];
    let carl = accounts[3];

    before(async ()=>{
        SwarmAdContract = await SwarmAd.deployed();
        GovernorContract = await Governor.deployed();
        RewarderContract = await Rewarder.deployed();

        SWRPContract = await SWRP.new(RewarderContract.address);
        SWCTContract = await SWCT.new(RewarderContract.address);
    });
  
    it("1) Create a new enterprise", async()=>{
        await SwarmAdContract.createEnterprise("alice", "alice@gmail.com", "0x1234", {from: alice});
        await SwarmAdContract.createEnterprise("bob", "bob@gmail.com", "0x5678", {from: bob});
    });

    it("2) Check enterprise in waiting list", async()=>{
        let result = await SwarmAdContract.isInWaitingList(bob);
        assert.equal(result, true, "Enterprise is not in waiting list");
    });

    it("3) Vote a proposal", async()=>{
        let polls = await GovernorContract.getAllPoll();
        await GovernorContract.castVote(polls[0], 1, {from:alice});
    });

    it("4) Execute a proposal", async()=>{
        let result = await SwarmAdContract.isRegistered(bob);
        assert.equal(result, false, "already registered");
        let day = 60 * 60 * 24;
        await time.increase(day*2);
        let polls = await GovernorContract.getAllPoll();
        await GovernorContract.closePoll(polls[0], {from: alice});
        result = await SwarmAdContract.isRegistered(bob);
        assert.equal(result, true, "user not added successfully");
    });

    it("5) Check rewards", async()=>{
        let result = await SWRPContract.balanceOf(alice);
        //assert.equal(result, 20, "Rewards not received");
    });

    it("6) New voting", async()=>{
        //newcomer
        await SwarmAdContract.createEnterprise("carl", "carl@gmail.com", "0x9101", {from: carl});
        //voting
        let polls = await GovernorContract.getAllPoll();
        await GovernorContract.castVote(polls[1], 1, {from:alice});
        await GovernorContract.castVote(polls[1], 1, {from:bob});
        //fast forward to vote end
        let day = 60 * 60 * 24;
        await time.increase(day+1);
        await GovernorContract.closePoll(polls[1], {from: bob});
        /*alice has new RPs, she should be able to redeem her first bunch of SWCT
        await RewarderContract.redeem({from: alice});
        ct = await SWCTContract.balanceOf(alice);
        assert.equal(ct, 20, "SWCT not properly converted");
        let rp = await SWRPContract.balanceOf(alice);
        assert.equal(rp, 30, "RP are wrong");
        let vault = await RewarderContract.getVaultValue(alice);
        assert.equal(vault, 0, "vault not empty after redeem");
        */
    });
});
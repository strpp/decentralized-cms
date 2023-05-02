const SwarmAd = artifacts.require("SwarmAd");
const Governor = artifacts.require("SwarmAdGovernor");
const Rewarder = artifacts.require("SwarmAdRewarder");
const SWCT = artifacts.require("SwarmAdCommunityToken");
const SWRP = artifacts.require("SwarmAdReputationPoints");
const { time } = require('../node_modules/@openzeppelin/test-helpers');

//accounts = available addresses in the network
contract("SwarmAd", (accounts) => {

    let SwarmAdContract, GovernorContract, SWCTContract, RewarderContract, SWRPContract;
    let user=accounts[0]
    let bob=accounts[1];
    let pid;

    before(async ()=>{
        SwarmAdContract = await SwarmAd.deployed();
        GovernorContract = await Governor.deployed();
        RewarderContract = await Rewarder.deployed();

        SWRPContract = await SWRP.new(RewarderContract.address);
        SWCTContract = await SWCT.new(RewarderContract.address);
    });
    
    it("create enterprise", async()=>{
        await SwarmAdContract.createEnterprise("juve", "juve@gmail.com", "0x1234", {from: user});
        let result = await SwarmAdContract.isRegistered(user);
        assert.equal(result, true, "Enterprises not registered");
    });

    it("remove enterprise", async()=>{
        await SwarmAdContract.removeEnterpriseFromSwarmAd({from: user});
        let result = await SwarmAdContract.isRegistered(user);
        assert.equal(result, false, "Enterprises is still registered");
    });

    it("check if remove enterprise removes also products", async()=>{
        await SwarmAdContract.createEnterprise("samp", "samp@gmail.com", "0x9001", {from: user});
        await SwarmAdContract.removeEnterpriseFromSwarmAd({from: user});
        let globalPidList= await SwarmAdContract.getProductList();
        assert.equal(globalPidList.length, 0, "Products not removed");
    });

    it("retrieve enterprise", async()=>{
        await SwarmAdContract.createEnterprise("samp", "samp@gmail.com", "0x9001", {from: user});
        let result = await SwarmAdContract.getEnterprise(user);
        assert.equal(result[0], "samp", "Enterprise is not retrieved");
    });

    it("change enterprise name", async()=>{
        await SwarmAdContract.updateEName("juventus", {from: user});
        let result = await SwarmAdContract.getEnterprise(user, {from: user});
        assert.equal(result[0], "juventus", "Name is not changed");
    });

    it("create new product", async()=>{
        await SwarmAdContract.createNewProduct("pogba", "pogba.jpg", "football player", "10", {from: user});
    });

    it("retrieve product by pid", async()=>{
        let pidList = await SwarmAdContract.getProductListFromEnterprise(user);
        pid = pidList[0];
        let result = await SwarmAdContract.getProductByPid(pid);
        assert.equal(result[0], "pogba", "Product name is not correct");
    });

    it("update name by pid", async()=>{
        await SwarmAdContract.updateProductNameByPid(pid, "dimaria",{from: user});
        let result = await SwarmAdContract.getProductByPid(pid);
        assert.equal(result[0], "dimaria", "item is not deleted");

    });

    it("use superlike", async()=>{
        await SwarmAdContract.createEnterprise("bob", "bob@gmail.com", "0x5678", {from: bob});
        let polls = await GovernorContract.getAllPoll();
        await GovernorContract.castVote(polls[0], 1, {from:user});
        let day = 60 * 60 * 24;
        await time.increase(day*1);
        await GovernorContract.closePoll(polls[0], {from: user});
        let pidList = await SwarmAdContract.getProductListFromEnterprise(user);
        await SwarmAdContract.assignSuperlike(pidList[0], {from: bob});
    });
});

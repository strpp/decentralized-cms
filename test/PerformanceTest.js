const SwarmAd = artifacts.require("SwarmAd");
const Governor = artifacts.require("SwarmAdGovernor");
const Rewarder = artifacts.require("SwarmAdRewarder");
const SWCT = artifacts.require("SwarmAdCommunityToken");
const SWRP = artifacts.require("SwarmAdReputationPoints");
const { time } = require('../node_modules/@openzeppelin/test-helpers');

//accounts = available addresses in the network
contract("Performance", (accounts) => {

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
    
    /*
    it("create 100 products", async()=>{
        await SwarmAdContract.createEnterprise("alice", "alice@gmail.com", "0x1234", {from: user});
        for(let i=0; i<100; i++){
            await SwarmAdContract.createNewProduct( `${i}`,  ` ${i}.jpg`, "item", "10", {from: user});
        }
    });
    */

    accounts.forEach(
        (i=>{
            it(`create enterprise ${i}`, async()=> {
                    await SwarmAdContract.createEnterprise(`User ${i}`, `${i}@gmail.com`, `${i}`, {from: i});
            })
        })
    );
        
});

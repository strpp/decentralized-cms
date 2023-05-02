const SwarmAd = artifacts.require("SwarmAd");
const SWRP = artifacts.require("SwarmAdReputationPoints");
const SWCT = artifacts.require("SwarmAdCommunityToken");
const Governor = artifacts.require("SwarmAdGovernor");
const Rewarder = artifacts.require("SwarmAdRewarder");

module.exports = function(deployer) {
  deployer.then(async () => {
    await deployer.deploy(SwarmAd);
    await deployer.deploy(Governor);
    await deployer.deploy(Rewarder);
    await deployer.deploy(SWRP, Rewarder.address);
    await deployer.deploy(SWCT, Rewarder.address);
  });
};


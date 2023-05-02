// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SwarmAd.sol";
import "./SwarmAdReputationPoints.sol";
import "./SwarmAdCommunityToken.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SwarmAdRewarder is AccessControl{

    uint256 dailyInterestRate = 1;

    /// @notice stores how much interest in form of Community Token users are accumulating
    mapping(address=>uint256) public SWCTVault;
    /// @notice keeps track of last time the interests have been computed for each wallet
    mapping(address=>uint256) private addressToLastInterestComputation;

    /// @notice access control mechanism
    address governor;
    address swarmad;
    address coins;
    address reputation;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    event newValueInVault(uint256 amount);
    event ValueInVault(address owner, uint256 amount);

    constructor() {
        swarmad = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x02) )))));
        governor = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x03))))));
        reputation = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x05) )))));
        coins = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x06) )))));
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, swarmad);    
        _setupRole(MINTER_ROLE, governor);
        _setupRole(GOVERNOR_ROLE, governor);
  }

    /// @notice  Computes interests
    /// @param balance reputation points a user has in his wallet
    /// @param a user
    /// @return uint256 how much interests a user has accumulateed from ladt computation
    function computeCompoundInterest(uint256 balance, address a) internal view returns(uint256){
        uint256 duration = SafeMath.sub(block.timestamp,addressToLastInterestComputation[a]);
        uint256 durationInDays = SafeMath.div( SafeMath.div (SafeMath.div(duration, 60), 60), 24);
        uint256 compoundInterest = SafeMath.mul( SafeMath.mul(durationInDays, balance), dailyInterestRate);
        return compoundInterest;
    }

    /// @notice  Add reputation points to a user's wallet
    /// @param a user ethereum address
    /// @param amount how many RP
    function addRPsToAccount(address a, uint256 amount) public onlyRole(MINTER_ROLE) {
        SwarmAdReputationPoints SWRP = SwarmAdReputationPoints(reputation);
        uint256 balance = SWRP.balanceOf(a);
        uint256 interest = computeCompoundInterest(balance, a);
        if(interest>0){
            uint256 newVaultValue = SafeMath.add(SWCTVault[a], interest);
            SWCTVault[a] = newVaultValue;
        }
        SWRP.mint(a, amount);
        addressToLastInterestComputation[a] = block.timestamp;
    }

    /// @notice  Burn reputation points from a user's wallet
    /// @param a user ethereum address
    /// @param amount how many RP
    function burnRPsToAccount(address a, uint256 amount) public onlyRole(GOVERNOR_ROLE){
        SwarmAdReputationPoints SWRP = SwarmAdReputationPoints(reputation);
        uint256 balance = SWRP.balanceOf(a);
        uint256 interest = computeCompoundInterest(balance, a);
        if(interest>0){
            uint256 newVaultValue = SafeMath.add(SWCTVault[a], interest);
            SWCTVault[a] = newVaultValue;
        }
        SWRP.burn(a, amount);
        addressToLastInterestComputation[a] = block.timestamp;
    }

    /// @notice  converts interests into Community Token
    function redeem() public{
        uint256 amount = SWCTVault[msg.sender];
        require(amount>0);
        SWCTVault[msg.sender] = 0;
        SwarmAdCommunityToken SWCT = SwarmAdCommunityToken(coins);
        SWCT.mint(msg.sender, amount);
    }
}
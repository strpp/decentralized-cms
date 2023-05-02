// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SwarmAd.sol";
import "./SwarmAdRewarder.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/Math.sol";

contract SwarmAdGovernor is AccessControl{

    /// @notice Other contracts' addresses
    address swarmad;
    address rewarder;

    /// @notice Translates pollId into Poll object
    mapping (uint=>Poll) pollMap;

    /// @notice List with all pollId since mapping is not iterable
    uint[] polls;

    /// @notice voting time (currently 1 day)
    uint256 votingDelay = 86400;

    /// @notice quorum in percentage to reach to make a poll valid
    uint256 quorum = 51;

    /// @notice slashing reputation score of who doesn't vote
    uint256 punishment = 10;

    /// @notice poll state
    uint64 constant ACTIVE = 1;
    uint64 constant CLOSED = 2;
    uint64 constant EXECUTED = 3;

    struct Poll{
        uint64 state;
        uint64 votesFor;
        uint64 votesAgainst;
        uint64 votesNull;
        uint256 pollId;
        uint256 maxVoters;
        uint256 quorum;
        uint256 votingStart;
        uint256 votingEnd;
        address swarmad;
        address proposer;
        address [] voters;
        address [] ableToVote;
        bytes[] calldatas;
        string description;
    }

    event pollCreated(uint256 pollId, string description);
    event pollExecuted(uint256 pollId);
    event assignCloseReward(uint256 amount, uint256 delayInHours, uint256 delayFactor);

    constructor() {
        swarmad = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x02))))));
        rewarder = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), msg.sender, bytes1(0x04))))));
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice  Compute the number of voters is needed to reach the quorum
    /// @param maxVoters users with voting right for the current poll
    /// @return res i.e. quorum expressed in users
    function computeQuorum(uint256 maxVoters) internal view returns(uint256){
        uint256 prod = SafeMath.mul(maxVoters, quorum);
        uint256 res = SafeMath.div(prod, 100);
        return res;
    }

    /// @notice  Create a poll
    /// @param proposer user or contract who is creating the poll
    /// @param calldatas function to execute if the majority voted for
    /// @param description  string with the poll reason
    function createPoll(address proposer, bytes[] memory calldatas, string memory description) public {
        uint256 pollId = uint(keccak256(abi.encodePacked(block.timestamp, proposer)));
        //External call to SwarmAd to get current list of users
        address[] memory maxVoters = SwarmAd(swarmad).getEList(); 
        require(maxVoters.length > 0);

        Poll storage p = pollMap[pollId];
        p.pollId = pollId;
        p.proposer = proposer;
        p.ableToVote = maxVoters;
        p.maxVoters = maxVoters.length;
        p.quorum = computeQuorum(maxVoters.length);
        p.votingStart = block.timestamp;
        p.votingEnd = block.timestamp + votingDelay;
        p.state = ACTIVE;
        p.calldatas = calldatas;
        p.description = description;
        polls.push(pollId);

        emit pollCreated(pollId, description);
    }

    /// @notice  Retrieve a poll from global list
    /// @param pollId uint unique identifier
    function getPoll(uint pollId) public view returns(
        address proposer, uint64 votesFor, uint64 votesAgainst, uint64 votesNull,
        uint256 numberVoters, uint256 votingEnd
        ){
        Poll memory p = pollMap[pollId];
        return (p.proposer, p.votesFor, p.votesAgainst, p.votesNull, p.voters.length, p.votingEnd);
    }

    /// @notice  Execute the function embeeded in the poll
    /// @param pollId uint unique identifier
    function executePoll(uint pollId) internal{
        require(hasVotingRight(pollId, msg.sender));
        (bool success, bytes memory returndata) = swarmad.call(pollMap[pollId].calldatas[0]);
        Address.verifyCallResult(success, returndata, "Governor: reverted without message");
    }

    /// @notice Close the poll if the deadline is met
    /// @param pollId uint unique identifier
    function closePoll(uint pollId) public{
        require(!isVotingActive(pollId), "Governor: Poll is still active");
        require(!isPollExecuted(pollId), "Governor: Poll has already been executed");
        require(hasVotingRight(pollId, msg.sender), "Governor: User has no voting right to close the poll");
        if(!isQuorumReached(pollId)){
            pollMap[pollId].state=CLOSED;
        } 
        if(isMajorityVotingFor(pollId) ){
            executePoll(pollId);
        }
        else if(pollMap[pollId].swarmad != pollMap[pollId].proposer){
            SwarmAdRewarder(rewarder).burnRPsToAccount(pollMap[pollId].proposer, punishment);
        }
        giveRewards(pollId);
        pollMap[pollId].state = EXECUTED;
        emit pollExecuted(pollId);
    }

    /// @notice  Check if user a voted in poll
    /// @param poll uint unique identifier
    /// @param a user
    function hasNotVoted(uint poll, address a) internal view returns(bool){
        address[] memory voters = pollMap[poll].voters;
        for(uint i=0; i<voters.length; i++){
            if(voters[i]==a) return false;
        }
        return true;
    }

    /// @notice  Check if a poll has been already executed
    /// @param pollId uint unique identifier
    /// @return bool
    function isPollExecuted(uint pollId) public view returns(bool){
        if(pollMap[pollId].state == EXECUTED) return true;
        return false;
    }

    /// @notice  Check if a poll deadline is already met
    /// @param poll uint unique identifier
    /// @return bool
    function isVotingActive(uint poll) public view returns(bool) {
        if(block.timestamp > pollMap[poll].votingEnd) return false;
        if(block.timestamp < pollMap[poll].votingStart) return false;
        return true;
    }

    /// @notice  Check if quorum is reached
    /// @param pollId uint unique identifier
    /// @return bool
    function isQuorumReached(uint pollId) internal view returns(bool){
        if(pollMap[pollId].voters.length > pollMap[pollId].quorum) return true;
        return false;
    }

    /// @notice  Check if majority voted for, hence if poll has to be executed
    /// @param pollId uint unique identifier
    /// @return bool
    function isMajorityVotingFor(uint pollId) internal view returns(bool){
        Poll memory p = pollMap[pollId];
        if(p.votesFor > p.votesAgainst) return true;
        return false;
    }

    /// @notice  Check users who voted and who did not, calls the rewarder to mint or burn reputation points
    /// @param pollId uint unique identifier
    function giveRewards(uint pollId) internal {
        require(hasVotingRight(pollId, msg.sender), "Governor: no right to vote");
        SwarmAdRewarder Rewarder  = SwarmAdRewarder(rewarder);
        uint256 amount = 10; //TODO
        address[] memory voters = pollMap[pollId].voters;
        for(uint i=0; i<voters.length; i++){
            if(hasNotVoted(pollId, voters[i])) Rewarder.burnRPsToAccount(voters[i], amount);
            else Rewarder.addRPsToAccount(voters[i], amount);
        }
        uint256 delay = SafeMath.sub(block.timestamp, pollMap[pollId].votingEnd);
        uint256 delayInHours = SafeMath.div(SafeMath.div(delay, 60), 60);
        uint256 delayFactor = Math.max(1, delayInHours);
        uint256 closeReward = SafeMath.div(amount, delayFactor);
        emit assignCloseReward(closeReward, delayInHours, delayFactor);
        Rewarder.addRPsToAccount(msg.sender, closeReward);
    }

    /// @notice  Check if a user can vote for that poll
    /// @param poll uint unique identifier
    /// @param a user
    /// @return bool
    function hasVotingRight(uint poll, address a) internal view returns(bool){
        address[] memory ableToVote = pollMap[poll].ableToVote;
        for(uint i = 0; i<ableToVote.length; i++){
            if(ableToVote[i]==a) return true;
        }
        return false;
    }

    /// @notice  Cast vote from a user
    /// @param poll uint unique identifier
    /// @param vote 1 = for, 2 = against, 3 = abstained
    function castVote(uint poll, uint64 vote) public{
        require(hasVotingRight(poll, msg.sender));
        require(isVotingActive(poll));
        require(hasNotVoted(poll, msg.sender));
        
        if(vote==1) pollMap[poll].votesFor++;
        if(vote==2) pollMap[poll].votesAgainst++;
        if(vote==3) pollMap[poll].votesNull++;

        pollMap[poll].voters.push(msg.sender);
    }

    /// @notice  Get all polls created
    function getAllPoll() public view returns(uint[] memory pollList){
        return polls;
    }



}
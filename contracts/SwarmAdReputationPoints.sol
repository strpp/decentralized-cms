// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";

contract SwarmAdReputationPoints is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address rewarder) ERC20("SwarmAdReputationPoints", "SWRP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, rewarder);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20){
        require(from == address(0) || to == address(0), "Error: Reputation Points are not transferable");
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) public onlyRole(MINTER_ROLE){
        _burn(to, amount);
    }


}

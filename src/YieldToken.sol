// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


contract YieldToken is ERC20, Ownable {
    address public fundsVault;

    constructor() ERC20("YieldToken", "YLD") Ownable(msg.sender) {}

    modifier onlyFundsVault() {
        require(msg.sender == fundsVault, "Only FundsVault");
        _;
    }

    function mint(address to, uint256 amount) external onlyFundsVault {
        _mint(to, amount * 10**6);
    }

    function burnFrom(address from, uint256 amount) external onlyFundsVault {
        _burn(from, amount);
    }

    function sellYieldTokens(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient YLD");
        uint256 userShare = (amount * 80) / 100; // 80% of YIELD TOKEN goes to the user, 20% to the PLATFORM
        uint256 platformShare = amount - userShare;

        _burn(msg.sender, amount);
        emit Transfer(msg.sender, address(0), platformShare); // Burn platform share
        // this call will transfer YT to the caller back
        transfer(msg.sender, userShare); // Transfer user share
    }

    function setFundsVault(address _fundsVault) external onlyOwner {
        fundsVault = _fundsVault;
    }

     function decimals() public view override returns(uint8) {
        return 6;
    }
}
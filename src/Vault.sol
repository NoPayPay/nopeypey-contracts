// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MockAaveLendingPool } from "./MockAavePool.sol";
import { PrincipalToken } from "./PrincipalToken.sol";
import { YieldToken } from "./YieldToken.sol";
import { Treasury } from "./Treasury.sol";

contract FundsVault is Ownable {
    IERC20 public immutable usdc;
    MockAaveLendingPool public aavePool;
    PrincipalToken public principalToken;
    YieldToken public yieldToken;
    Treasury public treasury;

    mapping(address => uint256) public depositTimes;
    mapping(address => bool) public fundsClaimed;

    constructor(
        address _initialOwner,
        address _usdc,
        address _aavePool,
        address _treasury,
        address _principalToken,
        address _yieldToken
    ) Ownable(_initialOwner) {
        usdc = IERC20(_usdc);
        aavePool = MockAaveLendingPool(_aavePool);
        treasury = Treasury(_treasury);
        principalToken = PrincipalToken(_principalToken);
        yieldToken = YieldToken(_yieldToken);
    }

    function deposit(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        principalToken.mint(msg.sender, amount);
        yieldToken.mint(msg.sender, amount * 10 / 100); // 10% of deposit
        aavePool.deposit(address(usdc), amount, address(this), 0);
        depositTimes[msg.sender] = block.timestamp;
        fundsClaimed[msg.sender] = false;
    }

    function harvestYield() external onlyOwner {
        uint256 yieldAmount = aavePool.calculateYield(address(this));
        require(yieldAmount > 0, "No yield available");
        treasury.collectFee(yieldAmount);
    }

    function withdrawPrincipal() external {
        require(
            block.timestamp - depositTimes[msg.sender] >= 90 days,
            "90-day lockup not completed"
        );
        require(!fundsClaimed[msg.sender], "Already claimed");

        uint256 principalAmount = principalToken.balanceOf(msg.sender);
        require(principalAmount > 0, "No principal to withdraw");

        principalToken.burn(msg.sender, principalAmount);
        aavePool.withdraw(address(usdc), principalAmount, msg.sender);
        fundsClaimed[msg.sender] = true;
    }

    function claimFunds(address user) external onlyOwner {
        require(
            block.timestamp - depositTimes[user] < 90 days,
            "Lockup period expired"
        );
        require(!fundsClaimed[user], "Already claimed");

        uint256 amount = principalToken.balanceOf(user);
        require(amount > 0, "No funds to claim");

        principalToken.burn(user, amount);
        aavePool.withdraw(address(usdc), amount, address(treasury));
        fundsClaimed[user] = true;
    }
}
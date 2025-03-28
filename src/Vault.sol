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
       InitialSetup memory initialParams
    ) Ownable(initialParams._initialOwner) {
        usdc = IERC20(initialParams._usdc);
        aavePool = MockAaveLendingPool(initialParams._aavePool);
        treasury = Treasury(initialParams._treasury);
        principalToken = PrincipalToken(initialParams._principalToken);
        yieldToken = YieldToken(initialParams._yieldToken);
    }


    struct InitialSetup {
        address _initialOwner;
        address _usdc;
        address _aavePool;
        address _treasury;
        address _principalToken;
        address _yieldToken;
    }

    function deposit(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        principalToken.mint(msg.sender, amount);
        // why does only 10% of the deposited amount is minted to the user ???
        yieldToken.mint(msg.sender, amount * 10 / 100); // 10% of deposit
        // approving mock aave pool to pull the funds
        usdc.approve(address(aavePool), amount);
        aavePool.deposit(address(usdc), amount, address(this), 0);
        depositTimes[msg.sender] = block.timestamp;
        fundsClaimed[msg.sender] = false;
    }

    /**
     * @dev harvesting yield from the pool
     */
    function harvestYield() external onlyOwner returns(uint256) {
        // this function should be call by user not owner
        uint256 yieldAmount;
        unchecked {
            yieldAmount = aavePool.calculateYield(address(this));
        }
        // 10% of farmed yield goes to the platform, rest go to the user and paid merchant
        require(yieldAmount > 0, "No yield available");
        // either one of these functions could be commented out
        aavePool.distributeYield(address(this));
        usdc.approve(address(treasury), yieldAmount);
        treasury.collectFee(yieldAmount);
        return yieldAmount;
    }

    /**
     * @dev user withdrawing their principal assets from the pool goes directly to the user
     */
    function withdrawPrincipal() external {
        require(
            block.timestamp >= (depositTimes[msg.sender] + 90 days),
            "90-day lockup not completed"
        );
        require(!fundsClaimed[msg.sender], "Already claimed");

        uint256 principalAmount = principalToken.balanceOf(msg.sender);
        require(principalAmount > 0, "No principal to withdraw");

        principalToken.burn(msg.sender, principalAmount);
        aavePool.withdraw(address(usdc), principalAmount, msg.sender);
        fundsClaimed[msg.sender] = true;
    }

    /**
     * @dev getting user funds back from the pool goes into treasury
     * @param user - user address
     */
    function claimFunds(address user) external onlyOwner returns(uint256 claimedAmount) {
        require(
            block.timestamp <= (depositTimes[msg.sender] + 90 days),
            "Lockup period expired"
        );
        require(!fundsClaimed[user], "Already claimed");

        uint256 amount = principalToken.balanceOf(user);
        require(amount > 0, "No funds to claim");

        principalToken.burn(user, amount);
        aavePool.withdraw(address(usdc), amount, address(treasury));
        fundsClaimed[user] = true;
        claimedAmount = amount;
    }
}
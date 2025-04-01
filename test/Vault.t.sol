// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { MockAaveLendingPool } from "../src/MockAavePool.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { YieldToken } from "../src/YieldToken.sol";
import { PrincipalToken } from "../src/PrincipalToken.sol";
import {Treasury } from "../src/Treasury.sol";
import { FundsVault } from "../src/Vault.sol";

contract VaultTest is Test {

    MockUSDC usdc;
    FundsVault vault;
    YieldToken yieldtoken;
    PrincipalToken principal;
    Treasury treasury;
    MockAaveLendingPool mockAavePool;

    address INITIAL_OWNER = makeAddr("OWNER");
    address MERCHANT = makeAddr("MERCHANT");
    uint256 TEST_DEPO_AMOUNT = 100e6;

    function setUp() public {
        vm.deal(INITIAL_OWNER, 20 ether);

        vm.startPrank(INITIAL_OWNER);
        usdc = new MockUSDC();
        yieldtoken = new YieldToken();
        principal = new PrincipalToken();
        treasury = new Treasury(address(usdc));
        mockAavePool = new MockAaveLendingPool(address(usdc));

        vault = new FundsVault(FundsVault.InitialSetup(INITIAL_OWNER, address(usdc), address(mockAavePool), address(treasury), address(principal), address(yieldtoken)));

        // setting Vault address
        principal.setFundsVault(address(vault));
        yieldtoken.setFundsVault(address(vault));

        // add an initial funds to the vault contract
        usdc.transfer(address(vault), 1000e6); // 1000 usdc
         vm.stopPrank();
    }

    modifier Deposited() {
        vm.startPrank(INITIAL_OWNER);
        usdc.approve(address(vault), TEST_DEPO_AMOUNT);
        vault.deposit(TEST_DEPO_AMOUNT, 90 days);
        _;
    }

    function test_depositAndWithdrawAsset() public {
        uint256 passedlockPeriod = block.timestamp + 90 days;
        uint256 balanceBfore = usdc.balanceOf(INITIAL_OWNER);
        console.log("balance before", balanceBfore);

        vm.startPrank(INITIAL_OWNER);
        usdc.approve(address(vault), TEST_DEPO_AMOUNT);
        vault.deposit(TEST_DEPO_AMOUNT, 90 days);
        uint256 balanceAfter = usdc.balanceOf(INITIAL_OWNER);
        console.log("balance after", balanceAfter);

        vm.warp(passedlockPeriod); // passing the lockup period
        vault.withdrawPrincipal();
        uint256 balanceAfterWd = usdc.balanceOf(INITIAL_OWNER);
        console.log("balance WD", balanceAfterWd);

        vm.stopPrank();

        assert(balanceAfter < balanceBfore);
    }

    function test_withdrawPrincipalAsset() public Deposited {
        uint256 passedlockPeriod = block.timestamp + 90 days;
      
        uint256 balanceAfterDeposit = usdc.balanceOf(INITIAL_OWNER);
        console.log("balance after", balanceAfterDeposit);

        vm.warp(passedlockPeriod); // passing the lockup period
        vault.withdrawPrincipal();
        uint256 balanceAfterWd = usdc.balanceOf(INITIAL_OWNER);
        console.log("balance WD", balanceAfterWd);

        vm.stopPrank();

        assert(balanceAfterDeposit < balanceAfterWd);
    }

    function test_withdrawBeforeUnlockTime() public Deposited {
        uint256 passedlockPeriod = block.timestamp + 10 days;
        vm.warp(passedlockPeriod); // passing the lockup period
        vm.expectRevert("90-day lockup not completed");
        vault.withdrawPrincipal();
        // uint256 balanceAfterWd = usdc.balanceOf(INITIAL_OWNER);
        // console.log("balance WD", balanceAfterWd);
        vm.stopPrank();
    }

    function test_harvestYield() public Deposited {
        uint256 afterSometime = block.timestamp + 300 days;
        vm.warp(afterSometime);
        uint256 yieldAmount = vault.harvestYield();

        console.log("after yield amount", yieldAmount);
        vm.stopPrank();
    }

    function test_harvestZeroYield() public Deposited {
        uint256 afterSometime = block.timestamp;
        vm.warp(afterSometime);
        vm.expectRevert("No yield available");
        uint256 yieldAmount = vault.harvestYield();

        console.log("after yield amount", yieldAmount);
        vm.stopPrank();
    }

    function test_claimingFunds() public Deposited {
        uint256 passedlockPeriod = block.timestamp + 10 days;
        vm.warp(passedlockPeriod);
        uint256 claimedAmount = vault.claimFunds(INITIAL_OWNER);

        console.log(claimedAmount);
        vm.stopPrank();
    }

    function test_payingMerchant() public Deposited {
        uint256 balanceMerchantBfore = usdc.balanceOf(MERCHANT);
        uint256 amountToPay = 50e6;
        console.log("before payment", balanceMerchantBfore);

        vault.payMerchant(amountToPay, MERCHANT);
        uint256 balanceMerchantAfter = usdc.balanceOf(MERCHANT);
        console.log("after getting paid", balanceMerchantAfter);

        vm.stopPrank();
        assert(balanceMerchantAfter > balanceMerchantBfore);
        
    }

    function test_payingMerchantExceededTheirDepositedAmount() public Deposited {
        uint256 balanceMerchantBfore = usdc.balanceOf(MERCHANT);
        uint256 amountToPay = 150e6;
        console.log("before payment", balanceMerchantBfore);

        vm.expectRevert("Insufficient funds to cover the payment");
        vault.payMerchant(amountToPay, MERCHANT);
        vm.stopPrank();
        
    }

    function test_getDecimal() public {
        uint256 ytDecimals = yieldtoken.decimals();
        uint256 ptDecimals = principal.decimals();
        uint256 usdcDecimals = usdc.decimals();

        console.log("YT",ytDecimals);
        console.log("PT", ptDecimals);
        console.log("USDC", usdcDecimals);
    } 

}
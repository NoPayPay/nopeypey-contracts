// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { MockAaveLendingPool } from "../src/MockAavePool.sol";
import { MockUSDC } from "../src/MockUSDC.sol";
import { YieldToken } from "../src/YieldToken.sol";
import { PrincipalToken } from "../src/PrincipalToken.sol";
import {Treasury } from "../src/Treasury.sol";
import { FundsVault } from "../src/Vault.sol";


/**
 * @dev this deploy scripts for all contracts deployment, combined just for simplicity
 */

contract DeployScript is Script {
    MockUSDC usdc;
    FundsVault vault;
    YieldToken yieldtoken;
    PrincipalToken principal;
    Treasury treasury;
    MockAaveLendingPool mockAavePool;

    address INITIAL_OWNER = 0xdaFE88244735b360F26Ab97cA560853866E302E4;

    function run() public {
        vm.startBroadcast(INITIAL_OWNER);
        usdc = new MockUSDC();
        yieldtoken = new YieldToken();
        principal = new PrincipalToken();
        treasury = new Treasury(address(usdc));
        mockAavePool = new MockAaveLendingPool(address(usdc));

        vault = new FundsVault(FundsVault.InitialSetup(INITIAL_OWNER, address(usdc), address(mockAavePool), address(treasury), address(principal), address(yieldtoken)));

        principal.setFundsVault(address(vault));
        yieldtoken.setFundsVault(address(vault));
        usdc.transfer(address(vault), 50000e6);

        console.log("vault usdc balance", usdc.balanceOf(address(vault)));

        vm.stopBroadcast();
    }

}
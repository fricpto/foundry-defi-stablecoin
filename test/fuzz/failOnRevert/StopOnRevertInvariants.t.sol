// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StopOnRevertHandler} from "./StopOnRevertHandler.t.sol";

contract StopOnRevertInvariants is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dsce;
    HelperConfig config;
    DecentralizedStableCoin dsc;
    StopOnRevertHandler handler;
    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(dsce));
        handler = new StopOnRevertHandler(dsce, dsc);
        targetContract(address(handler));
    }
    // forge-config: default.invariant.fail-on-revert = false

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get the value of all the collateral in the protocol
        // compare it to all the dept (dsc)
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalwbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));
        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalwbtcDeposited);
        console.log("Weth total deposited", wethValue);
        console.log("Wbtc total deposited", wbtcValue);
        console.log("Total supply of DSC", totalSupply);
        console.log("Times Mint is Called:", handler.timesMintIsCalled());
        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
        dsce.getLiquidationBonus();
        dsce.getPrecision();
        dsce.getAdditionalFeedPrecision();
        dsce.getCollateralTokens();
        dsce.getLiquidationThreshold();
        dsce.getMinHealthFactor();
        dsce.getDsc();
        /* dsce.getTokenAmountFromUsd();
        dsce.getCollateralTokenPriceFeed();
        dsce.getCollateralBalanceOfUser();
        dsce.getAccountCollateralValue(); */
    }
}

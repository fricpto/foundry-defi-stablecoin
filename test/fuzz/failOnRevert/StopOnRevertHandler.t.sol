// narrow down the way that we call functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {console} from "forge-std/console.sol";

contract StopOnRevertHandler is Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 private MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dsce.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(wbtc)));
    }
    ///////////////
    // DSCEngine //
    ///////////////

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE); //  min + (input % (max - min + 1)) 1+(amountCollateral%(MAX_DEPOSIT_SIZE-1+1))
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }
    ///////////////
    // DSCEngine //
    ///////////////

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        if (amountCollateral == 0) {
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amountDsc, uint256 adressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[adressSeed % usersWithCollateralDeposited.length];
        //amountDsc = bound(amountDsc, 1, MAX_DEPOSIT_SIZE);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        uint256 maxDscToMint = (collateralValueInUsd / 2) - totalDscMinted;
        if (maxDscToMint == 0) {
            return;
        }
        amountDsc = bound(amountDsc, 0, maxDscToMint);
        if (amountDsc == 0) {
            return;
        }
        vm.startPrank(sender);

        dsce.mintDsc(amountDsc);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 minHealthFactor = dsce.getMinHealthFactor();
        uint256 userHealthFactor = dsce.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dsce.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }
    /////////////////////////////
    // DecentralizedStableCoin //
    /////////////////////////////

    function transferDsc(uint256 amountDsc, address to) public {
        if (to == address(0)) {
            to = address(1);
        }
        amountDsc = bound(amountDsc, 0, dsc.balanceOf(msg.sender));
        vm.prank(msg.sender);
        dsc.transfer(to, amountDsc);
    }

    /////////////////////////////
    // Aggregator //
    /////////////////////////////

    /* function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 intNewPrice = int256(uint256(newPrice));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        MockV3Aggregator priceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(collateral)));

        priceFeed.updateAnswer(intNewPrice);
    } */

    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }

    /// Helper Functions

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}

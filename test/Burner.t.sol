// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOperatorRewards} from "./mocks/MockOperatorRewards.sol";
import {MockVaultConfigurator} from "./mocks/MockVaultConfigurator.sol";
import {Controller} from "../src/Controller.sol";
import {Burner} from "../src/Burner.sol";
import {NetworkMiddleware} from "../src/NetworkMiddleware.sol";
import {CoverTokenFactory} from "../src/cover/CoverTokenFactory.sol";
import {CoverToken} from "../src/cover/CoverToken.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {IVaultConfigurator} from "lib/core/src/interfaces/IVaultConfigurator.sol";

contract BurnerTest is Test {
    uint48 constant EPOCH_DURATION = 7 days;

    Controller public controller;
    NetworkMiddleware public middleware;
    CoverTokenFactory public factory;
    Burner public burner;

    MockERC20 public baseAsset;
    MockERC20 public supportedAsset1;
    MockERC20 public supportedAsset2;

    address public keeper;
    address public user;

    function setUp() public {
        // Deploy mock tokens
        baseAsset = new MockERC20("Base Asset", "BASE");
        supportedAsset1 = new MockERC20("Supported Asset 1", "SUP1");
        supportedAsset2 = new MockERC20("Supported Asset 2", "SUP2");

        // Setup addresses
        keeper = makeAddr("keeper");
        user = makeAddr("user");

        // Deploy core contracts
        CoverToken implementation = new CoverToken();

        // Replace deployCode with mock contracts
        IDefaultOperatorRewards operatorRewards = new MockOperatorRewards();
        IVaultConfigurator vaultConfigurator = new MockVaultConfigurator();

        // Deploy burner after controller is initialized
        burner = new Burner();

        middleware = new NetworkMiddleware(
            operatorRewards,
            vaultConfigurator,
            address(burner)
        );
        factory = new CoverTokenFactory(address(implementation));

        address[] memory supportedAssets = new address[](2);
        supportedAssets[0] = address(supportedAsset1);
        supportedAssets[1] = address(supportedAsset2);

        controller = new Controller(
            address(factory),
            address(middleware),
            keeper
        );

        // Transfer middleware ownership to controller
        middleware.transferOwnership(address(controller));

        controller.initialize(
            address(baseAsset),
            EPOCH_DURATION,
            address(this),
            supportedAssets
        );

        // Initialize burner
        burner.initialize(address(controller), address(baseAsset));
    }

    function test_deployment() public {
        assertEq(address(burner.controller()), address(controller));
        assertEq(burner.baseAsset(), address(baseAsset));
        
        // Check supported assets were imported correctly
        assertTrue(burner.isAssetSupported(address(supportedAsset1)));
        assertTrue(burner.isAssetSupported(address(supportedAsset2)));

        // Check cover token mappings
        assertEq(
            burner.coveredAssetToCoverToken(address(supportedAsset1)),
            controller.coveredAssetToCoverToken(address(supportedAsset1))
        );
        assertEq(
            burner.coveredAssetToCoverToken(address(supportedAsset2)), 
            controller.coveredAssetToCoverToken(address(supportedAsset2))
        );
    }

    function test_claimCoverage() public {
        // TODO: Implement after CoverToken burn functionality is added
        // Should test:
        // - Transfer of cover tokens from user to burner
        // - Burning of cover tokens
        // - Transfer of base asset to user
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
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
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";

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
    address public user2;

    function setUp() public {
        // Deploy mock tokens
        baseAsset = new MockERC20("Base Asset", "BASE");
        supportedAsset1 = new MockERC20("Supported Asset 1", "SUP1");
        supportedAsset2 = new MockERC20("Supported Asset 2", "SUP2");

        // Setup addresses
        keeper = makeAddr("keeper");
        user = makeAddr("user");
        user2 = makeAddr("user2");

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
        // Get vault address
        address vaultAddr = controller.vault();
        
        // Mint base asset to user for vault deposit
        baseAsset.mint(user, 100e18);
        
        // User deposits base asset to vault
        vm.startPrank(user);
        baseAsset.approve(vaultAddr, 100e18);
        IVault(vaultAddr).deposit(user, 100e18);
        vm.stopPrank();

        // User2 buys cover for supported asset 1
        vm.startPrank(user2);
        controller.buyCover(address(supportedAsset1), 50e18);
        
        // Mint some supported asset to user2 for claiming
        supportedAsset1.mint(user2, 50e18);
        
        // Approve burner to spend tokens
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        MockERC20(coverToken).approve(address(burner), 50e18);
        supportedAsset1.approve(address(burner), 50e18);
        vm.stopPrank();

        // Mock the slash call
        address validator = makeAddr("validator");
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                NetworkMiddleware.slash.selector,
                vaultAddr,
                validator,
                50e18,
                uint48(block.timestamp)
            ),
            abi.encode()
        );

        // Mock the vault's onSlash to transfer base asset to burner
        vm.mockCall(
            vaultAddr,
            abi.encodeWithSelector(
                IVault.onSlash.selector,
                50e18,
                uint48(block.timestamp)
            ),
            abi.encode(50e18)  // Return slashed amount
        );

        // Keeper executes slash which triggers vault to send funds to burner
        vm.prank(keeper);
        controller.executeSlash(validator, 50e18, uint48(block.timestamp));

        // Transfer base asset to burner (simulating vault's behavior)
        baseAsset.mint(address(burner), 50e18);

        // User2 claims coverage
        vm.startPrank(user2);
        burner.claimCoverage(address(supportedAsset1), 50e18);

        // Verify balances after claim
        assertEq(MockERC20(coverToken).balanceOf(user2), 0); // Cover tokens burned
        assertEq(supportedAsset1.balanceOf(user2), 0); // Supported asset transferred
        assertEq(baseAsset.balanceOf(user2), 50e18); // Base asset received
        vm.stopPrank();
    }
}

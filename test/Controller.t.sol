// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "lib/forge-std/src/Test.sol";
import {Controller} from "../src/Controller.sol";
import {CoverToken} from "../src/cover/CoverToken.sol";
import {CoverTokenFactory} from "../src/cover/CoverTokenFactory.sol";
import {NetworkMiddleware} from "../src/NetworkMiddleware.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOperatorRewards} from "./mocks/MockOperatorRewards.sol";
import {MockVaultConfigurator} from "./mocks/MockVaultConfigurator.sol";
import {IVaultConfigurator} from "lib/core/src/interfaces/IVaultConfigurator.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {INetworkMiddleware} from "../src/interfaces/INetworkMiddleware.sol";

contract ControllerTest is Test {
    Controller public controller;
    CoverTokenFactory public factory;
    NetworkMiddleware public middleware;
    MockERC20 public baseAsset;
    MockERC20 public supportedAsset1;
    MockERC20 public supportedAsset2;
    address public keeper;
    address public user;
    address public user2;
    uint48 constant EPOCH_DURATION = 7 days;

    function setUp() public {
        // Deploy mock tokens
        baseAsset = new MockERC20("Base Asset", "BASE");
        supportedAsset1 = new MockERC20("Supported Asset 1", "SUP1");
        supportedAsset2 = new MockERC20("Supported Asset 2", "SUP2");

        // Setup addresses
        keeper = makeAddr("keeper");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        address burner = makeAddr("burner");

        // Deploy core contracts
        CoverToken implementation = new CoverToken();

        // Replace deployCode with mock contracts
        IDefaultOperatorRewards operatorRewards = new MockOperatorRewards();
        IVaultConfigurator vaultConfigurator = new MockVaultConfigurator();

        middleware = new NetworkMiddleware(
            operatorRewards,
            vaultConfigurator,
            burner
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

        // Mint tokens to users
        baseAsset.mint(user, 1000e18);
        baseAsset.mint(user2, 1000e18);
    }

    function test_deployment() public {
        setUp();
    }

    function test_depositAndBuyCover() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // User approves and deposits base asset to vault
        vm.startPrank(user);
        baseAsset.approve(vaultAddr, 100e18);
        IVault(vaultAddr).deposit(user, 100e18);
        vm.stopPrank();

        // User2 buys cover for supported asset 1
        vm.startPrank(user2);
        baseAsset.approve(address(controller), 50e18);
        controller.buyCover(address(supportedAsset1), 50e18);
        vm.stopPrank();

        // Verify cover token balance
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        assertEq(IERC20(coverToken).balanceOf(user2), 50e18);
    }
    function test_buyCoverRevertsWhenUnsupportedAsset() public {
        vm.startPrank(user);
        baseAsset.approve(address(controller), 50e18);
        
        address randomAsset = makeAddr("randomAsset");
        vm.expectRevert(Controller.NoCoverTokenForAsset.selector);
        controller.buyCover(randomAsset, 50e18);
        vm.stopPrank();
    }

    function test_buyCoverRevertsWhenAmountExceedsCapacity() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // User deposits small amount to vault
        vm.startPrank(user);
        baseAsset.approve(vaultAddr, 10e18);
        IVault(vaultAddr).deposit(user, 10e18);
        vm.stopPrank();

        // Mock the getVaultActiveBalance call to return 10e18
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.getVaultActiveBalance.selector, vaultAddr, address(controller)),
            abi.encode(10e18)
        );

        // User2 tries to buy more cover than vault capacity
        vm.startPrank(user2);
        baseAsset.approve(address(controller), 21e18);
        vm.expectRevert(abi.encodeWithSelector(Controller.AmountExceedsCapacity.selector, 21e18, 20e18));
        controller.buyCover(address(supportedAsset1), 21e18);
        vm.stopPrank();
    }

    function test_buyCoverForMultipleAssets() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // User deposits base asset to vault
        vm.startPrank(user);
        baseAsset.approve(vaultAddr, 200e18);
        IVault(vaultAddr).deposit(user, 200e18);
        vm.stopPrank();

        // User2 buys cover for both supported assets
        vm.startPrank(user2);
        baseAsset.approve(address(controller), 100e18);
        
        controller.buyCover(address(supportedAsset1), 50e18);
        controller.buyCover(address(supportedAsset2), 50e18);

        // Verify cover token balances
        address coverToken1 = controller.coveredAssetToCoverToken(address(supportedAsset1));
        address coverToken2 = controller.coveredAssetToCoverToken(address(supportedAsset2));
        
        assertEq(IERC20(coverToken1).balanceOf(user2), 50e18);
        assertEq(IERC20(coverToken2).balanceOf(user2), 50e18);
        vm.stopPrank();
    }

function test_executeSlash() public {
        address vaultAddr = controller.vault();
        address validator = makeAddr("validator");

        vm.startPrank(user);
        vm.expectRevert(Controller.NotKeeper.selector);
        controller.executeSlash(validator, 100e18, uint48(block.timestamp));
        vm.stopPrank();

        // Mock successful slash call
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, 100e18, uint48(block.timestamp)),
            abi.encode()
        );

        vm.expectCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, 100e18, uint48(block.timestamp))
        );

        vm.startPrank(keeper);
        controller.executeSlash(validator, 100e18, uint48(block.timestamp));
        vm.stopPrank();
}}

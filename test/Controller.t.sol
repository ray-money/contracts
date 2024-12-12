// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Controller} from "../src/Controller.sol";
import {CoverToken} from "../src/cover/CoverToken.sol";
import {CoverTokenFactory} from "../src/cover/CoverTokenFactory.sol";
import {NetworkMiddleware} from "../src/NetworkMiddleware.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockOperatorRewards} from "./mocks/MockOperatorRewards.sol";
import {MockVaultConfigurator} from "./mocks/MockVaultConfigurator.sol";
import {IVaultConfigurator} from "lib/core/src/interfaces/IVaultConfigurator.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";

import {console} from "forge-std/console.sol";


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
        IVault(vaultAddr).deposit(100e18, user);
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
}

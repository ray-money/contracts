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
    MockERC20 public collateralAsset;
    MockERC20 public supportedAsset1;
    MockERC20 public supportedAsset2;
    address public keeper;
    address public liquidityProvider;
    address public coverageBuyer;
    uint48 constant EPOCH_DURATION = 7 days;
    uint256 constant INITIAL_LIQUIDITY_PROVIDER_BALANCE = 1000e18;
    uint256 constant INITIAL_COVERAGE_BUYER_BALANCE = 1000e18;
    uint256 constant VAULT_DEPOSIT_AMOUNT = 100e18;
    uint256 constant COVER_AMOUNT = 50e18;
    uint256 constant SMALL_DEPOSIT = 10e18;
    uint256 constant LARGE_COVER_AMOUNT = 21e18;
    uint256 constant LARGE_DEPOSIT = 200e18;
    uint256 constant MAX_CAPACITY = 20e18;

    function setUp() public {
        // Deploy mock tokens
        collateralAsset = new MockERC20("Collateral Asset", "BASE");
        supportedAsset1 = new MockERC20("Supported Asset 1", "SUP1");
        supportedAsset2 = new MockERC20("Supported Asset 2", "SUP2");

        // Setup addresses
        keeper = makeAddr("keeper");
        liquidityProvider = makeAddr("liquidityProvider");
        coverageBuyer = makeAddr("coverageBuyer");
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
            address(collateralAsset),
            EPOCH_DURATION,
            address(this),
            supportedAssets
        );

    }

    function test_deployment() public {
        setUp();
        
        // Verify initial state
        assertEq(controller.keeper(), keeper);
        assertEq(controller.collateralAsset(), address(collateralAsset));
        assertTrue(controller.isSupportedAsset(address(supportedAsset1)));
        assertTrue(controller.isSupportedAsset(address(supportedAsset2)));
        assertEq(address(controller.coverTokenFactory()), address(factory));
        assertEq(address(controller.networkMiddleware()), address(middleware));
    }

    function test_depositAndBuyCover() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // Liquidity provider approves and deposits collateral asset to vault
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(vaultAddr, VAULT_DEPOSIT_AMOUNT);
        IVault(vaultAddr).deposit(liquidityProvider, VAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Coverage buyer buys cover for supported asset 1
        vm.startPrank(coverageBuyer);
        collateralAsset.approve(address(controller), COVER_AMOUNT);
        controller.buyCover(address(supportedAsset1), COVER_AMOUNT);
        vm.stopPrank();

        // Verify cover token balance
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        assertEq(IERC20(coverToken).balanceOf(coverageBuyer), COVER_AMOUNT);
    }

    function test_buyCoverRevertsWhenUnsupportedAsset() public {
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(address(controller), COVER_AMOUNT);
        
        address randomAsset = makeAddr("randomAsset");
        vm.expectRevert(Controller.NoCoverTokenForAsset.selector);
        controller.buyCover(randomAsset, COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_buyCoverRevertsWhenAmountExceedsCapacity() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // Liquidity provider deposits small amount to vault
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(vaultAddr, SMALL_DEPOSIT);
        IVault(vaultAddr).deposit(liquidityProvider, SMALL_DEPOSIT);
        vm.stopPrank();

        // Mock the getVaultActiveBalance call to return 10e18
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.getVaultActiveBalance.selector, vaultAddr, address(controller)),
            abi.encode(SMALL_DEPOSIT)
        );

        // Coverage buyer tries to buy more cover than vault capacity
        vm.startPrank(coverageBuyer);
        collateralAsset.approve(address(controller), LARGE_COVER_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(Controller.AmountExceedsCapacity.selector, LARGE_COVER_AMOUNT, MAX_CAPACITY));
        controller.buyCover(address(supportedAsset1), LARGE_COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_buyCoverForMultipleAssets() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // Liquidity provider deposits collateral asset to vault
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(vaultAddr, LARGE_DEPOSIT);
        IVault(vaultAddr).deposit(liquidityProvider, LARGE_DEPOSIT);
        vm.stopPrank();

        // Coverage buyer buys cover for both supported assets
        vm.startPrank(coverageBuyer);
        collateralAsset.approve(address(controller), VAULT_DEPOSIT_AMOUNT);
        
        controller.buyCover(address(supportedAsset1), COVER_AMOUNT);
        controller.buyCover(address(supportedAsset2), COVER_AMOUNT);

        // Verify cover token balances
        address coverToken1 = controller.coveredAssetToCoverToken(address(supportedAsset1));
        address coverToken2 = controller.coveredAssetToCoverToken(address(supportedAsset2));
        
        assertEq(IERC20(coverToken1).balanceOf(coverageBuyer), COVER_AMOUNT);
        assertEq(IERC20(coverToken2).balanceOf(coverageBuyer), COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_executeSlash() public {
        address vaultAddr = controller.vault();
        address validator = makeAddr("validator");

        vm.startPrank(liquidityProvider);
        vm.expectRevert(Controller.NotKeeper.selector);
        controller.executeSlash(validator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp));
        vm.stopPrank();

        // Mock successful slash call
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp)),
            abi.encode()
        );

        vm.expectCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp))
        );

        vm.startPrank(keeper);
        controller.executeSlash(validator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp));
        vm.stopPrank();
    }

    function test_executeSlashWithZeroAmount() public {
        address vaultAddr = controller.vault();
        address validator = makeAddr("validator");

        // Mock successful slash call with zero amount
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, 0, uint48(block.timestamp)),
            abi.encode()
        );

        vm.expectCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.slash.selector, vaultAddr, validator, 0, uint48(block.timestamp))
        );

        vm.startPrank(keeper);
        controller.executeSlash(validator, 0, uint48(block.timestamp));
        vm.stopPrank();
    }

    function test_claimCoverage() public {
        // Get vault address
        address vaultAddr = controller.vault();
        
        // Mint collateral asset to liquidity provider for vault deposit
        collateralAsset.mint(liquidityProvider, VAULT_DEPOSIT_AMOUNT);
        
        // Liquidity provider deposits collateral asset to vault
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(vaultAddr, VAULT_DEPOSIT_AMOUNT);
        IVault(vaultAddr).deposit(liquidityProvider, VAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();

        // Coverage buyer buys cover for supported asset 1
        vm.startPrank(coverageBuyer);
        controller.buyCover(address(supportedAsset1), COVER_AMOUNT);
        
        // Mint some supported asset to coverage buyer for claiming
        supportedAsset1.mint(coverageBuyer, COVER_AMOUNT);
        
        // Approve controller to spend tokens
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        MockERC20(coverToken).approve(address(controller), COVER_AMOUNT);
        supportedAsset1.approve(address(controller), COVER_AMOUNT);
        vm.stopPrank();

        // Mock the slash call
        address validator = makeAddr("validator");
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                NetworkMiddleware.slash.selector,
                vaultAddr,
                validator,
                COVER_AMOUNT,
                uint48(block.timestamp)
            ),
            abi.encode()
        );

        // Mock the vault's onSlash to transfer collateral asset to controller
        vm.mockCall(
            vaultAddr,
            abi.encodeWithSelector(
                IVault.onSlash.selector,
                COVER_AMOUNT,
                uint48(block.timestamp)
            ),
            abi.encode(COVER_AMOUNT)  // Return slashed amount
        );

        // Keeper executes slash which triggers vault to send funds to controller
        vm.prank(keeper);
        controller.executeSlash(validator, COVER_AMOUNT, uint48(block.timestamp));

        // Transfer collateral asset to controller (simulating vault's behavior)
        collateralAsset.mint(address(controller), COVER_AMOUNT);

        // Coverage buyer claims coverage
        vm.startPrank(coverageBuyer);
        controller.claimCoverage(address(supportedAsset1), COVER_AMOUNT);

        // Verify balances after claim
        assertEq(MockERC20(coverToken).balanceOf(coverageBuyer), 0); // Cover tokens burned
        assertEq(supportedAsset1.balanceOf(coverageBuyer), 0); // Supported asset transferred
        assertEq(collateralAsset.balanceOf(coverageBuyer), COVER_AMOUNT); // Collateral asset received
        vm.stopPrank();
    }

    function test_buyCoverRevertsWhenZeroAmount() public {
        vm.startPrank(coverageBuyer);
        vm.expectRevert(Controller.InvalidAmount.selector);
        controller.buyCover(address(supportedAsset1), 0);
        vm.stopPrank();
    }

    function test_claimCoverageRevertsWhenZeroAmount() public {
        vm.startPrank(coverageBuyer);
        vm.expectRevert(Controller.InvalidAmount.selector);
        controller.claimCoverage(address(supportedAsset1), 0);
        vm.stopPrank();
    }

}

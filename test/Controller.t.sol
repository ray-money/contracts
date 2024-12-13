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

import {console} from "lib/forge-std/src/console.sol";

contract ControllerTest is Test {
    // ============ Storage ============

    Controller public controller;
    CoverTokenFactory public factory;
    NetworkMiddleware public middleware;
    MockERC20 public collateralAsset;
    MockERC20 public supportedAsset1;
    MockERC20 public supportedAsset2;
    
    address public keeper;
    address public liquidityProvider;
    address public coverageBuyer;

    // ============ Constants ============

    uint48 constant EPOCH_DURATION = 7 days;
    uint256 constant INITIAL_LIQUIDITY_PROVIDER_BALANCE = 1000e18;
    uint256 constant INITIAL_COVERAGE_BUYER_BALANCE = 1000e18;
    uint256 constant VAULT_DEPOSIT_AMOUNT = 100e18;
    uint256 constant COVER_AMOUNT = 50e18;
    uint256 constant SMALL_DEPOSIT = 10e18;
    uint256 constant LARGE_COVER_AMOUNT = 21e18;
    uint256 constant LARGE_DEPOSIT = 200e18;
    uint256 constant MAX_CAPACITY = 20e18;

    // ============ Setup ============

    function setUp() public {
        _deployMockTokens();
        _setupAddresses();
        _deployContracts();
        _initializeController();
    }

    function _deployMockTokens() internal {
        collateralAsset = new MockERC20("Collateral Asset", "BASE");
        supportedAsset1 = new MockERC20("Supported Asset 1", "SUP1");
        supportedAsset2 = new MockERC20("Supported Asset 2", "SUP2");
    }

    function _setupAddresses() internal {
        keeper = makeAddr("keeper");
        liquidityProvider = makeAddr("liquidityProvider");
        coverageBuyer = makeAddr("coverageBuyer");
    }

    function _deployContracts() internal {
        CoverToken implementation = new CoverToken();
        IDefaultOperatorRewards operatorRewards = new MockOperatorRewards();
        IVaultConfigurator vaultConfigurator = new MockVaultConfigurator();

        middleware = new NetworkMiddleware(
            operatorRewards,
            vaultConfigurator,
            makeAddr("burner")
        );
        factory = new CoverTokenFactory(address(implementation));

        controller = new Controller(
            address(factory),
            address(middleware),
            keeper
        );

        middleware.updateBurner(address(controller));
        middleware.transferOwnership(address(controller));
    }

    function _initializeController() internal {
        address[] memory supportedAssets = new address[](2);
        supportedAssets[0] = address(supportedAsset1);
        supportedAssets[1] = address(supportedAsset2);

        controller.initialize(
            address(collateralAsset),
            EPOCH_DURATION,
            address(this),
            supportedAssets
        );
    }

    // ============ Test Cases ============

    function test_deployment() public {
        setUp();
        
        assertEq(controller.keeper(), keeper);
        assertEq(controller.collateralAsset(), address(collateralAsset));
        assertTrue(controller.isSupportedAsset(address(supportedAsset1)));
        assertTrue(controller.isSupportedAsset(address(supportedAsset2)));
        assertEq(address(controller.coverTokenFactory()), address(factory));
        assertEq(address(controller.networkMiddleware()), address(middleware));
        assertEq(middleware.burner(), address(controller));
    }

    function test_depositAndBuyCover() public {
        address vaultAddr = controller.vault();
        
        _depositToVault(liquidityProvider, vaultAddr, VAULT_DEPOSIT_AMOUNT);
        _buyCover(coverageBuyer, address(supportedAsset1), COVER_AMOUNT);

        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        assertEq(IERC20(coverToken).balanceOf(coverageBuyer), COVER_AMOUNT);
    }

    function test_buyCoverRevertsWhenUnsupportedAsset() public {
        vm.startPrank(liquidityProvider);
        collateralAsset.approve(address(controller), COVER_AMOUNT);
        
        vm.expectRevert(Controller.NoCoverTokenForAsset.selector);
        controller.buyCover(makeAddr("randomAsset"), COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_buyCoverRevertsWhenAmountExceedsCapacity() public {
        address vaultAddr = controller.vault();
        
        _depositToVault(liquidityProvider, vaultAddr, SMALL_DEPOSIT);

        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(INetworkMiddleware.getVaultActiveBalance.selector, vaultAddr, address(controller)),
            abi.encode(SMALL_DEPOSIT)
        );

        vm.startPrank(coverageBuyer);
        collateralAsset.approve(address(controller), LARGE_COVER_AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(Controller.AmountExceedsCapacity.selector, LARGE_COVER_AMOUNT, MAX_CAPACITY));
        controller.buyCover(address(supportedAsset1), LARGE_COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_buyCoverForMultipleAssets() public {
        address vaultAddr = controller.vault();
        
        _depositToVault(liquidityProvider, vaultAddr, LARGE_DEPOSIT);

        vm.startPrank(coverageBuyer);
        collateralAsset.approve(address(controller), VAULT_DEPOSIT_AMOUNT);
        
        controller.buyCover(address(supportedAsset1), COVER_AMOUNT);
        controller.buyCover(address(supportedAsset2), COVER_AMOUNT);

        address coverToken1 = controller.coveredAssetToCoverToken(address(supportedAsset1));
        address coverToken2 = controller.coveredAssetToCoverToken(address(supportedAsset2));
        
        assertEq(IERC20(coverToken1).balanceOf(coverageBuyer), COVER_AMOUNT);
        assertEq(IERC20(coverToken2).balanceOf(coverageBuyer), COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_executeSlash() public {
        address vaultAddr = controller.vault();
        address operator = makeAddr("operator");
        
        // Setup initial state
        _depositToVault(liquidityProvider, vaultAddr, VAULT_DEPOSIT_AMOUNT);
        _mockAllocateStake(vaultAddr, operator, VAULT_DEPOSIT_AMOUNT);
        _allocateStake(liquidityProvider, operator, VAULT_DEPOSIT_AMOUNT);
        _mockSlash(vaultAddr, operator, VAULT_DEPOSIT_AMOUNT);
        
        // Execute slash
        vm.prank(keeper);
        controller.executeSlash(operator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp));
    }

    function test_executeSlashWithZeroAmount() public {
        address vaultAddr = controller.vault();
        address operator = makeAddr("operator");

        _mockSlash(vaultAddr, operator, 0);

        vm.prank(keeper);
        controller.executeSlash(operator, 0, uint48(block.timestamp));
    }

    function test_executeSlashRevertsWhenNotKeeper() public {
        address operator = makeAddr("operator");

        vm.expectRevert(Controller.NotKeeper.selector);
        vm.prank(liquidityProvider);
        controller.executeSlash(operator, VAULT_DEPOSIT_AMOUNT, uint48(block.timestamp));
    }

    function test_claimCoverage() public {
        address vaultAddr = controller.vault();
        address operator = makeAddr("operator");
        
        _setupClaimScenario(vaultAddr);
        _mockSlashAndVaultBehavior(vaultAddr, operator);

        vm.prank(keeper);
        controller.executeSlash(operator, COVER_AMOUNT, uint48(block.timestamp));

        collateralAsset.mint(address(controller), COVER_AMOUNT);

        vm.startPrank(coverageBuyer);
        controller.claimCoverage(address(supportedAsset1), COVER_AMOUNT);

        _verifyClaimBalances();
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

    function test_initializeRevertsWhenAlreadyInitialized() public {
        address[] memory supportedAssets = new address[](2);
        supportedAssets[0] = address(supportedAsset1);
        supportedAssets[1] = address(supportedAsset2);

        vm.expectRevert(Controller.AlreadyInitialized.selector);
        controller.initialize(
            address(collateralAsset),
            EPOCH_DURATION,
            address(this),
            supportedAssets
        );
    }

    function test_allocateOperatorStakeRevertsWhenInsufficientBalance() public {
        address vaultAddr = controller.vault();
        address operator = makeAddr("operator");
        
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                INetworkMiddleware.getVaultActiveBalance.selector,
                vaultAddr,
                liquidityProvider
            ),
            abi.encode(SMALL_DEPOSIT)
        );

        vm.startPrank(liquidityProvider);
        vm.expectRevert(abi.encodeWithSelector(
            Controller.InsufficientBalance.selector,
            SMALL_DEPOSIT,
            VAULT_DEPOSIT_AMOUNT
        ));
        controller.allocateOperatorStake(operator, VAULT_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function test_claimCoverageRevertsWhenNoCoverToken() public {
        address randomAsset = makeAddr("randomAsset");
        
        // Verify the asset is not supported and has no cover token
        assertFalse(controller.isSupportedAsset(randomAsset));
        assertEq(controller.coveredAssetToCoverToken(randomAsset), address(0));
        
        vm.startPrank(coverageBuyer);
        vm.expectRevert(Controller.NoCoverTokenForAsset.selector);
        controller.claimCoverage(randomAsset, COVER_AMOUNT);
        vm.stopPrank();
    }

    function test_buyCoverRevertsWhenCapacityExceeded() public {
        address vaultAddr = controller.vault();
        
        _depositToVault(liquidityProvider, vaultAddr, SMALL_DEPOSIT);

        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                INetworkMiddleware.getVaultActiveBalance.selector,
                vaultAddr,
                address(controller)
            ),
            abi.encode(SMALL_DEPOSIT)
        );

        vm.startPrank(coverageBuyer);
        vm.expectRevert(abi.encodeWithSelector(
            Controller.AmountExceedsCapacity.selector,
            LARGE_COVER_AMOUNT,
            MAX_CAPACITY
        ));
        controller.buyCover(address(supportedAsset1), LARGE_COVER_AMOUNT);
        vm.stopPrank();
    }

    // ============ Helper Functions ============

    function _depositToVault(address depositor, address vault, uint256 amount) internal {
        vm.startPrank(depositor);
        collateralAsset.approve(vault, amount);
        IVault(vault).deposit(depositor, amount);
        vm.stopPrank();
    }

    function _buyCover(address buyer, address asset, uint256 amount) internal {
        vm.startPrank(buyer);
        collateralAsset.approve(address(controller), amount);
        controller.buyCover(asset, amount);
        vm.stopPrank();
    }

    function _mockAllocateStake(address vault, address operator, uint256 amount) internal {
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                INetworkMiddleware.allocateStake.selector,
                vault,
                operator,
                amount
            ),
            abi.encode()
        );
    }

    function _allocateStake(address staker, address operator, uint256 amount) internal {
        vm.prank(staker);
        controller.allocateOperatorStake(operator, amount);
    }

    function _mockSlash(address vault, address operator, uint256 amount) internal {
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                INetworkMiddleware.slash.selector,
                vault,
                operator,
                amount,
                uint48(block.timestamp)
            ),
            abi.encode()
        );

        vm.expectCall(
            address(middleware),
            abi.encodeWithSelector(
                INetworkMiddleware.slash.selector,
                vault,
                operator,
                amount,
                uint48(block.timestamp)
            )
        );
    }

    function _setupClaimScenario(address vault) internal {
        collateralAsset.mint(liquidityProvider, VAULT_DEPOSIT_AMOUNT);
        
        _depositToVault(liquidityProvider, vault, VAULT_DEPOSIT_AMOUNT);

        vm.startPrank(coverageBuyer);
        controller.buyCover(address(supportedAsset1), COVER_AMOUNT);
        
        supportedAsset1.mint(coverageBuyer, COVER_AMOUNT);
        
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        MockERC20(coverToken).approve(address(controller), COVER_AMOUNT);
        supportedAsset1.approve(address(controller), COVER_AMOUNT);
        vm.stopPrank();
    }

    function _mockSlashAndVaultBehavior(address vault, address operator) internal {
        vm.mockCall(
            address(middleware),
            abi.encodeWithSelector(
                NetworkMiddleware.slash.selector,
                vault,
                operator,
                COVER_AMOUNT,
                uint48(block.timestamp)
            ),
            abi.encode()
        );

        vm.mockCall(
            vault,
            abi.encodeWithSelector(
                IVault.onSlash.selector,
                COVER_AMOUNT,
                uint48(block.timestamp)
            ),
            abi.encode(COVER_AMOUNT)
        );
    }

    function _verifyClaimBalances() internal view {
        address coverToken = controller.coveredAssetToCoverToken(address(supportedAsset1));
        assertEq(MockERC20(coverToken).balanceOf(coverageBuyer), 0);
        assertEq(supportedAsset1.balanceOf(coverageBuyer), 0);
        assertEq(collateralAsset.balanceOf(coverageBuyer), COVER_AMOUNT);
    }
}

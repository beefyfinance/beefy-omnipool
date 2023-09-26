pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {OptimismBridgeAdapter} from "../../../contracts/bridgeToken/adapters/optimism/OptimismBridgeAdapter.sol";
import {IOptimismBridge} from "../../../contracts/bridgeToken/adapters/optimism/IOptimismBridge.sol";
import {BIFI} from "../../../contracts/bridgeToken/BIFI.sol";
import {XERC20} from "../../../contracts/bridgeToken/XERC20.sol";
import {XERC20Factory} from "../../../contracts/bridgeToken/XERC20Factory.sol";
import {XERC20Lockbox} from "../../../contracts/bridgeToken/XERC20Lockbox.sol";
import {IXERC20} from '../../../contracts/bridgeToken/interfaces/IXERC20.sol';
import {IXERC20Lockbox} from '../../../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol';

contract OptimismBridgeTest is Test {
    address constant zero = 0x0000000000000000000000000000000000000000;
    address constant opbridge = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address constant user = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    BIFI bifi;
    address xbifi;
    address lockbox;
    XERC20Factory factory;
    OptimismBridgeAdapter bridge;
    address[] contracts;

    error WrongSender();

    address[] zeros;
    uint256[] mintAmounts;
    uint256 mintAmount = 80000 ether;

     function setUp() public {
        mintAmounts.push(mintAmount);
        zeros.push(zero);
        bifi = new BIFI();
        factory = new XERC20Factory();
        xbifi = factory.deployXERC20(
            "Beefy",
            "BIFI",
            mintAmounts,
            mintAmounts,
            zeros
        );

        lockbox = factory.deployLockbox(
            xbifi,
            address(bifi),
            false
        );

        contracts.push(address(opbridge));
        bridge = new OptimismBridgeAdapter();
        bridge.initialize(IERC20(address(bifi)), IXERC20(xbifi), IXERC20Lockbox(lockbox), contracts);
        IXERC20(address(xbifi)).setLimits(address(bridge), mintAmount, mintAmount);
    }

    function test_bridge_out() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 10;

        bridge.bridge(dstChainId, 10 ether, user);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 10 ether);
        assertEq(userBal, 0);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }

    function test_malicous_mint() public {
        vm.startPrank(user);

        vm.expectRevert(WrongSender.selector);
        bridge.mint(user, 10 ether);

        vm.stopPrank();
    }

    function test_bridge_in() public {
        vm.startPrank(address(opbridge));

        deal(address(bifi), lockbox, 10 ether);

        // Store this address as the variable in the xDomainMessanger slot on the opBridge.
        bytes32 bridgeBytes = bytes32(uint256(uint160(address(bridge))));
        vm.store(address(opbridge), 0x00000000000000000000000000000000000000000000000000000000000000cc, bridgeBytes);
        address sender = IOptimismBridge(opbridge).xDomainMessageSender();
        assertEq(sender, address(bridge));

        bridge.mint(user, 10 ether);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 0);
        assertEq(userBal, 10 ether);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }
}
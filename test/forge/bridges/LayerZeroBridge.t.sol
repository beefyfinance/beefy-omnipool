pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin-4/contracts/utils/cryptography/ECDSA.sol";
import {LayerZeroBridge} from "../../../contracts/bridgeToken/adapters/layerzero/LayerZeroBridge.sol";
import {IOptimismBridge} from "../../../contracts/bridgeToken/adapters/optimism/IOptimismBridge.sol";
import {BIFI} from "../../../contracts/bridgeToken/BIFI.sol";
import {XERC20} from "../../../contracts/bridgeToken/XERC20.sol";
import {XERC20Factory} from "../../../contracts/bridgeToken/XERC20Factory.sol";
import {XERC20Lockbox} from "../../../contracts/bridgeToken/XERC20Lockbox.sol";
import {IXERC20} from '../../../contracts/bridgeToken/interfaces/IXERC20.sol';
import {IXERC20Lockbox} from '../../../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol';

contract LayerZeroBridgeTest is Test {
    using ECDSA for bytes32;

    address constant zero = 0x0000000000000000000000000000000000000000;
    address constant endpoint = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
    address constant user = 0x810362e802692882720118616189A4361351c6f6;
    BIFI bifi;
    address xbifi;
    address lockbox;
    XERC20Factory factory;
    LayerZeroBridge bridge;
    address[] contracts;

    address[] zeros;
    uint256[] mintAmounts;
    uint256 mintAmount = 1000 ether;

    uint16 lzOpId = 111;
    uint256 opId = 10;
    uint256[] chainIds;
    uint16[] lzIds;

    error NoErrorFound();

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

        contracts.push(address(endpoint));
        bridge = new LayerZeroBridge();
        bridge.initialize(IERC20(address(bifi)), IXERC20(xbifi), IXERC20Lockbox(lockbox), contracts);
        IXERC20(address(xbifi)).setLimits(address(bridge), mintAmount, mintAmount);

        chainIds.push(opId);
        lzIds.push(lzOpId);
        bridge.addChainIds(chainIds, lzIds);
        bridge.setTrustedRemoteAddress(lzOpId, abi.encodePacked(address(bridge)));
        bridge.setGasLimit(2000000);
        vm.deal(user, 1 ether);
    }

    function test_bridge_out() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 10;
        uint16 lzId = bridge.chainIdToLzId(dstChainId);

        assertEq(lzId, lzOpId);

        uint256 gasNeeded = bridge.bridgeCost(dstChainId, 10 ether, user);

        bridge.bridge{value: gasNeeded}(dstChainId, 10 ether, user);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 10 ether);
        assertEq(userBal, 0);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }

    function test_bridge_fail() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 42161;

        vm.expectRevert(bytes("LzApp: destination chain is not a trusted source"));
        bridge.bridge(dstChainId, 10 ether, user);

        vm.stopPrank();
    }

    function test_malicous_mint() public {
        vm.startPrank(user);

        bytes memory payload = abi.encode(user, 10 ether);

        vm.expectRevert(bytes("LzApp: invalid endpoint caller"));
        bridge.lzReceive(lzOpId, abi.encode(""), 0, payload);
       
        vm.stopPrank();

        vm.startPrank(endpoint);

        vm.expectRevert(bytes("LzApp: invalid source sending contract"));
        bridge.lzReceive(42161, abi.encode(""), 0, payload);

        bytes memory trustedRemote = abi.encodePacked(abi.encodePacked(user), user);

        vm.expectRevert(bytes("LzApp: invalid source sending contract"));
        bridge.lzReceive(lzOpId, trustedRemote, 0, payload);
       
        vm.stopPrank();
    }

    function test_bridge_in() public {
        vm.startPrank(address(endpoint));

        deal(address(bifi), lockbox, 10 ether);

        bytes memory payload = abi.encode(user, 10 ether);
        bytes memory trustedRemote = abi.encodePacked(abi.encodePacked(address(bridge)), address(bridge));

        bridge.lzReceive(lzOpId, trustedRemote, 0, payload);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 0);
        assertEq(userBal, 10 ether);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }

     function test_retryBridge() public {
        vm.startPrank(address(endpoint));

        deal(address(bifi), lockbox, 2000 ether);

        bytes memory payload = abi.encode(user, 1000 ether);
        bytes memory trustedRemote = abi.encodePacked(abi.encodePacked(address(bridge)), address(bridge));

        uint256 approvalAmount = IERC20(address(xbifi)).allowance(address(bridge), address(lockbox));
        assertEq(approvalAmount, type(uint256).max);

        // User should get their first 1000 tokens.
        bridge.lzReceive(lzOpId, trustedRemote, 0, payload);

        uint256 amt = IERC20(address(bifi)).balanceOf(user);

        assertEq(amt, 1000 ether);

        payload = abi.encode(user, 10 ether);
        bridge.lzReceive(lzOpId, trustedRemote, 0, payload);

        amt = IERC20(address(bifi)).balanceOf(user);    
        assertEq(amt, 1000 ether);

        skip(1 days);
        bridge.retry(0);

        amt = IERC20(address(bifi)).balanceOf(user);
        assertEq(amt, 1010 ether);

        vm.expectRevert(NoErrorFound.selector);
        bridge.retry(0);

        vm.stopPrank();
    }
}
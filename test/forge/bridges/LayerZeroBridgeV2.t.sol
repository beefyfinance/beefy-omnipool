// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {LayerZeroBridge} from "../../../contracts/bridgeToken/adapters/layerzero/LayerZeroBridgeV2.sol";
import {BIFI} from "../../../contracts/bridgeToken/BIFI.sol";
import {XERC20Factory} from "../../../contracts/bridgeToken/XERC20Factory.sol";
import {IXERC20} from "../../../contracts/bridgeToken/interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {MessagingParams, MessagingFee, MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

// Minimal stand-in for EndpointV2 – accepts ETH fees
contract MockEndpointV2 {
    uint256 public constant FIXED_FEE = 0.001 ether;

    function setDelegate(address) external {}

    function quote(MessagingParams calldata, address) external pure returns (MessagingFee memory) {
        return MessagingFee(FIXED_FEE, 0);
    }

    function send(MessagingParams calldata, address) external payable returns (MessagingReceipt memory) {
        return MessagingReceipt(bytes32(0), 0, MessagingFee(FIXED_FEE, 0));
    }
}

contract LayerZeroBridgeV2Test is Test {
    address constant user = 0x810362e802692882720118616189A4361351c6f6;

    BIFI bifi;
    address xbifi;
    address lockbox;
    XERC20Factory factory;
    LayerZeroBridge bridge;
    MockEndpointV2 mockEndpoint;

    address[] zeros;
    uint256[] mintAmounts;
    uint256 mintAmount = 1000 ether;

    uint32 opEid = 30111; // LZ V2 Optimism endpoint ID
    uint256 opChainId = 10;
    uint256[] chainIds;
    uint32[] eids;

    error NoErrorFound();

    function setUp() public {
        mintAmounts.push(mintAmount);
        zeros.push(address(0));

        mockEndpoint = new MockEndpointV2();

        bifi = new BIFI();
        factory = new XERC20Factory();
        xbifi = factory.deployXERC20("Beefy", "BIFI", mintAmounts, mintAmounts, zeros);
        lockbox = factory.deployLockbox(xbifi, address(bifi), false);

        bridge = new LayerZeroBridge(address(mockEndpoint));
        bridge.initialize(IERC20(address(bifi)), IXERC20(xbifi), IXERC20Lockbox(lockbox), address(this));

        IXERC20(xbifi).setLimits(address(bridge), mintAmount, mintAmount);

        chainIds.push(opChainId);
        eids.push(opEid);
        bridge.addChainIds(chainIds, eids);
        bridge.setPeer(opEid, bytes32(uint256(uint160(address(bridge)))));
        // Minimal ExecutorLzReceiveOption: type(3) + worker(1) + length(16) + gas(200000) + value(0)
        bridge.setOptions(hex"0003010011010000000000000000000000000030d400");
    }

    function test_bridge_out() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);
        vm.deal(user, 1 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint256).max);

        uint256 gasNeeded = bridge.bridgeCost(opChainId, 10 ether, user);
        bridge.bridge{value: gasNeeded}(opChainId, 10 ether, user);

        assertEq(IERC20(address(bifi)).balanceOf(address(lockbox)), 10 ether);
        assertEq(IERC20(address(bifi)).balanceOf(user), 0);
        assertEq(IERC20(address(xbifi)).totalSupply(), 0);
        assertEq(user.balance, 1 ether - gasNeeded);

        vm.stopPrank();
    }

    function test_bridge_fail() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);
        IERC20(address(bifi)).approve(address(bridge), type(uint256).max);

        uint256 unknownChainId = 42161; // no peer set → NoPeer revert from OAppCore
        vm.expectRevert();
        bridge.bridge{value: 0.01 ether}(unknownChainId, 10 ether, user);

        vm.stopPrank();
    }

    function test_malicious_mint() public {
        bytes memory payload = abi.encode(user, 10 ether);
        Origin memory origin = Origin(opEid, bytes32(uint256(uint160(address(bridge)))), 0);

        vm.startPrank(user);
        vm.expectRevert(); // InvalidEndpointCall: caller is not the endpoint
        bridge.lzReceive(origin, bytes32(0), payload, address(0), "");
        vm.stopPrank();

        vm.startPrank(address(mockEndpoint));
        Origin memory wrongOrigin = Origin(opEid, bytes32(uint256(uint160(user))), 0);
        vm.expectRevert(); // OnlyPeer: sender bytes32 does not match stored peer
        bridge.lzReceive(wrongOrigin, bytes32(0), payload, address(0), "");
        vm.stopPrank();
    }

    function test_bridge_in() public {
        deal(address(bifi), lockbox, 10 ether);

        bytes memory payload = abi.encode(user, 10 ether);
        Origin memory origin = Origin(opEid, bytes32(uint256(uint160(address(bridge)))), 0);

        vm.startPrank(address(mockEndpoint));
        bridge.lzReceive(origin, bytes32(0), payload, address(0), "");
        vm.stopPrank();

        assertEq(IERC20(address(bifi)).balanceOf(address(lockbox)), 0);
        assertEq(IERC20(address(bifi)).balanceOf(user), 10 ether);
        assertEq(IERC20(address(xbifi)).totalSupply(), 0);
    }

    function test_retryBridge() public {
        deal(address(bifi), lockbox, 2000 ether);

        Origin memory origin = Origin(opEid, bytes32(uint256(uint160(address(bridge)))), 0);

        vm.startPrank(address(mockEndpoint));

        // First receive: consumes the full 1000 ether mint limit
        bytes memory payload = abi.encode(user, 1000 ether);
        bridge.lzReceive(origin, bytes32(0), payload, address(0), "");
        assertEq(IERC20(address(bifi)).balanceOf(user), 1000 ether);

        // Second receive: mint limit exhausted, stored as error[0]
        bytes memory payload2 = abi.encode(user, 10 ether);
        bridge.lzReceive(origin, bytes32(0), payload2, address(0), "");
        assertEq(IERC20(address(bifi)).balanceOf(user), 1000 ether);

        vm.stopPrank();

        skip(1 days); // XERC20 mint limit replenishes over time
        bridge.retry(0);
        assertEq(IERC20(address(bifi)).balanceOf(user), 1010 ether);

        vm.expectRevert(NoErrorFound.selector);
        bridge.retry(0);
    }
}

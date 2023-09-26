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
    uint256 mintAmount = 80000 ether;

    uint16 lzOpId = 111;
    uint256 opId = 10;
    uint256[] chainIds;
    uint16[] lzIds;

    uint256 signerPk;

     function setUp() public {

        // Just a test PK no live funds on this address
        signerPk = 0x951388a043b3665bed42537db0ae3745b36023af86a8f1cd185d269fb44667f7;
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

     function test_bridge_out_with_permit() public {
       // Wallet memory wallet = vm.createWallet();
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        uint256 dstChainId = 10;
        uint16 lzId = bridge.chainIdToLzId(dstChainId);

        assertEq(lzId, lzOpId);

        uint256 gasNeeded = bridge.bridgeCost(dstChainId, 10 ether, user);

        bytes32 typehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        uint256 nonce = IERC20Permit(address(bifi)).nonces(user);

        bytes32 DOMAIN_SEPARATOR = IERC20Permit(address(bifi)).DOMAIN_SEPARATOR();
        bytes32 digest = keccak256(abi.encode(
                        typehash,
                        user,
                        address(bridge),
                        uint256(10 ether),
                        nonce,
                        uint256(block.timestamp + 1000)));

        bytes32 withDomain = ECDSA.toTypedDataHash(DOMAIN_SEPARATOR, digest);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, withDomain);

        uint256 deadline = block.timestamp + 1000;

        bridge.bridge{value: gasNeeded}(user, dstChainId, 10 ether, user, deadline, v, r, s);

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
}
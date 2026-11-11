// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {LayerZeroBridgeV2} from "../../../contracts/bridgeToken/adapters/layerzero/LayerZeroBridgeV2.sol";
import {MinimalForkPlan as Plan} from "./MinimalForkPlan.sol";
import {DeployLZBridgeV2, IEndpointV2, UlnConfig} from "../../../scripts/DeployLZBridgeV2.s.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IXERC20} from "../../../contracts/bridgeToken/interfaces/IXERC20.sol";
import {
    ILayerZeroEndpointV2,
    Origin
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {PacketV1Codec} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/PacketV1Codec.sol";

interface ISafeFork {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function approveHash(bytes32 hashToApprove) external;
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce_
    ) external view returns (bytes32);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

interface IOwnedFork {
    function owner() external view returns (address);
}

interface IManagerFork {
    function xBIFI() external view returns (address);
    function keeper() external view returns (address);
}

interface ITimelockFork {
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IEndpointDelegate {
    function delegates(address oapp) external view returns (address);
}

interface IUlnFork {
    function getUlnConfig(address oapp, uint32 eid) external view returns (UlnConfig memory);
    function getAppUlnConfig(address oapp, uint32 eid) external view returns (UlnConfig memory);
    function getExecutorConfig(address oapp, uint32 eid)
        external
        view
        returns (uint32 maxMessageSize, address executor);
    function verify(bytes calldata header, bytes32 payloadHash, uint64 confirmations) external;
    function commitVerification(bytes calldata header, bytes32 payloadHash) external;
}

// Executes the SAME internal function as run(), with fork impersonation only.
// run(), PRIVATE_KEY and broadcast cheatcodes are never used by these tests.
contract MinimalDeploymentHarness is DeployLZBridgeV2 {
    function simulate(address deployer) external returns (address adapter) {
        vm.startPrank(deployer, deployer);
        adapter = _deployAndConfigure(deployer);
        vm.stopPrank();
    }
}

/// @notice Pinned pre-deployment forks; no transactions are broadcast.
/// @dev Run: forge test --match-contract LayerZeroBridgeV2ForkTest -vv
/// Override archive RPCs with ETH_RPC_URL, OP_RPC_URL and BASE_RPC_URL.
/// @dev Safe owner hash approvals, user funding and DVN attestations are impersonated.
/// Safe, timelock, TokenManager, xERC20, lockbox, CreateX, endpoint and ULN code are real fork state.
contract LayerZeroBridgeV2ForkTest is Test {
    using PacketV1Codec for bytes;

    address internal constant USER = address(0x123456789);
    address internal constant RELAYER = address(0x987654321);
    uint256[3] internal forks;

    struct Message {
        bytes header;
        bytes32 payloadHash;
        Origin origin;
        bytes32 guid;
        bytes payload;
        address receiver;
    }

    function setUp() public {
        string[3] memory urls = [
            vm.envOr("ETH_RPC_URL", string("https://mainnet.gateway.tenderly.co")),
            vm.envOr("OP_RPC_URL", string("https://mainnet.optimism.io")),
            vm.envOr("BASE_RPC_URL", string("https://base.gateway.tenderly.co"))
        ];
        for (uint256 i; i < 3; ++i) {
            Plan.Chain memory c = Plan.chain(i);
            forks[i] = vm.createSelectFork(urls[i], c.blockNumber);
            assertEq(block.chainid, c.chainId);
            assertEq(IOwnedFork(c.xToken).owner(), c.manager);
            assertEq(IOwnedFork(c.manager).owner(), c.timelock);
            assertEq(IManagerFork(c.manager).xBIFI(), c.xToken);
            assertEq(IManagerFork(c.manager).keeper(), Plan.KEEPER);
            assertEq(ITimelockFork(c.timelock).getMinDelay(), Plan.DELAY);
            assertTrue(ITimelockFork(c.timelock).hasRole(keccak256("PROPOSER_ROLE"), c.safe));
            assertTrue(ITimelockFork(c.timelock).hasRole(keccak256("EXECUTOR_ROLE"), Plan.KEEPER));
            assertEq(ISafeFork(c.safe).getThreshold(), 3);
            assertEq(Plan.predicted(c).code.length, 0, "Proposed adapter already exists");
            assertGt(c.executor.code.length, 0);
            assertEq(Plan.DEPLOYER.code.length, 0, "Deployer must be an EOA at the fork block");
            vm.setEnv("MSIG", vm.toString(c.safe));
            vm.setEnv("BIFI", vm.toString(c.token));
            vm.setEnv("XBIFI", vm.toString(c.xToken));
            vm.setEnv("LOCKBOX", vm.toString(c.lockbox));
            MinimalDeploymentHarness harness = new MinimalDeploymentHarness();
            address adapter = harness.simulate(Plan.DEPLOYER);
            assertEq(adapter, Plan.predicted(c));
            assertEq(IOwnedFork(adapter).owner(), c.safe);
            assertEq(IEndpointDelegate(Plan.ENDPOINT).delegates(adapter), c.safe);
            assertEq(IXERC20(c.xToken).mintingMaxLimitOf(adapter), 0);
            assertEq(IXERC20(c.xToken).burningMaxLimitOf(adapter), 0);
            _safeCall(c.safe, c.timelock, Plan.schedule(c, Plan.CANARY_LIMIT, Plan.CANARY_LIMIT));
            // Prove the 24h delay is enforced with the real keeper authority.
            vm.prank(Plan.KEEPER);
            (bool early,) = c.timelock.call(Plan.execute(c, Plan.CANARY_LIMIT, Plan.CANARY_LIMIT));
            assertFalse(early, "Timelock executed early");
            vm.warp(block.timestamp + Plan.DELAY + 1);
            vm.prank(Plan.KEEPER);
            (bool ok, bytes memory reason) = c.timelock.call(Plan.execute(c, Plan.CANARY_LIMIT, Plan.CANARY_LIMIT));
            if (!ok) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            }
            assertEq(IXERC20(c.xToken).mintingMaxLimitOf(Plan.predicted(c)), Plan.CANARY_LIMIT);
            assertEq(IXERC20(c.xToken).burningMaxLimitOf(Plan.predicted(c)), Plan.CANARY_LIMIT);
            vm.deal(USER, 10 ether);
            // Synthetic user funding only; no bridge, limit, or collateral storage is overwritten.
            deal(c.token, USER, 10 ether);
            vm.prank(USER);
            IERC20(c.token).approve(Plan.predicted(c), type(uint256).max);
        }
    }

    function _safeCall(address safe, address target, bytes memory data) internal {
        ISafeFork s = ISafeFork(safe);
        address[] memory owners = s.getOwners();
        for (uint256 i; i < owners.length; ++i) {
            for (uint256 j = i + 1; j < owners.length; ++j) {
                if (owners[i] > owners[j]) (owners[i], owners[j]) = (owners[j], owners[i]);
            }
        }
        bytes32 hash = s.getTransactionHash(target, 0, data, 0, 0, 0, 0, address(0), address(0), s.nonce());
        bytes memory signatures;
        uint256 threshold = s.getThreshold();
        for (uint256 i; i < threshold; ++i) {
            vm.prank(owners[i]);
            s.approveHash(hash);
            signatures = abi.encodePacked(signatures, bytes32(uint256(uint160(owners[i]))), bytes32(0), uint8(1));
        }
        assertTrue(s.execTransaction(target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures));
    }

    function test_formerDeployerHasNoAuthorityAfterHandoff() public {
        for (uint256 i; i < 3; ++i) {
            vm.selectFork(forks[i]);
            Plan.Chain memory c = Plan.chain(i);
            address adapter = Plan.predicted(c);
            uint256[] memory ids = new uint256[](1);
            uint32[] memory eids = new uint32[](1);
            Plan.Chain memory remote = Plan.chain((i + 1) % 3);
            ids[0] = remote.chainId;
            eids[0] = remote.eid;
            bytes[] memory calls = new bytes[](5);
            calls[0] = abi.encodeCall(LayerZeroBridgeV2.setOptions, (Plan.options()));
            calls[1] =
                abi.encodeWithSignature("setPeer(uint32,bytes32)", remote.eid, bytes32(uint256(uint160(adapter))));
            calls[2] = abi.encodeCall(LayerZeroBridgeV2.addChainIds, (ids, eids));
            calls[3] = abi.encodeWithSignature("setDelegate(address)", Plan.DEPLOYER);
            calls[4] = abi.encodeWithSignature("transferOwnership(address)", Plan.DEPLOYER);
            for (uint256 k; k < calls.length; ++k) {
                vm.prank(Plan.DEPLOYER, Plan.DEPLOYER);
                (bool allowed,) = adapter.call(calls[k]);
                assertFalse(allowed, "EOA retained adapter authority");
            }
            IEndpointV2.SetConfigParam[] memory params = new IEndpointV2.SetConfigParam[](1);
            UlnConfig memory config = IUlnFork(c.sendLib).getUlnConfig(adapter, remote.eid);
            config.optionalDVNCount = type(uint8).max;
            params[0] = IEndpointV2.SetConfigParam(remote.eid, 2, abi.encode(config));
            bytes memory configCall = abi.encodeCall(IEndpointV2.setConfig, (adapter, c.sendLib, params));
            vm.prank(Plan.DEPLOYER);
            (bool configured,) = Plan.ENDPOINT.call(configCall);
            assertFalse(configured, "EOA retained endpoint authority");
            vm.prank(Plan.DEPLOYER);
            (bool scheduled,) = c.timelock.call(Plan.schedule(c, 2 ether, 2 ether));
            assertFalse(scheduled);
            vm.prank(Plan.DEPLOYER);
            (bool enabled,) = c.manager.call(Plan.limitsData(c, 2 ether, 2 ether));
            assertFalse(enabled);
            // The receiving Safe can control both surfaces after handoff.
            _safeCall(c.safe, adapter, calls[0]);
            _safeCall(c.safe, Plan.ENDPOINT, configCall);
        }
    }

    function test_configurationAndAuthorityOnAllChains() public {
        for (uint256 i; i < 3; ++i) {
            vm.selectFork(forks[i]);
            Plan.Chain memory c = Plan.chain(i);
            LayerZeroBridgeV2 b = LayerZeroBridgeV2(Plan.predicted(c));
            assertEq(b.owner(), c.safe);
            assertEq(IEndpointDelegate(Plan.ENDPOINT).delegates(address(b)), c.safe);
            assertEq(address(b.BIFI()), c.token);
            assertEq(address(b.xBIFI()), c.xToken);
            assertEq(address(b.lockbox()), c.lockbox);
            assertEq(b.lzOptions(), Plan.options());
            assertEq(b.lzOptions().length, 22);
            assertEq(IXERC20(c.xToken).burningMaxLimitOf(Plan.OLD_BRIDGE), 0);
            assertEq(IXERC20(c.xToken).mintingMaxLimitOf(Plan.OLD_BRIDGE), i == 0 ? 124 ether : 0);
            assertEq(IXERC20(c.xToken).mintingMaxLimitOf(Plan.AXELAR), 2500 ether);
            assertEq(IXERC20(c.xToken).burningMaxLimitOf(Plan.AXELAR), 2500 ether);
            for (uint256 j; j < 3; ++j) {
                if (i == j) continue;
                Plan.Chain memory r = Plan.chain(j);
                assertEq(b.peers(r.eid), bytes32(uint256(uint160(Plan.predicted(r)))));
                assertEq(b.chainIdToEid(r.chainId), r.eid);
                assertEq(b.eidToChainId(r.eid), r.chainId);
                assertEq(ILayerZeroEndpointV2(Plan.ENDPOINT).getSendLibrary(address(b), r.eid), c.sendLib);
                (address receiveLibrary, bool usesDefault) =
                    ILayerZeroEndpointV2(Plan.ENDPOINT).getReceiveLibrary(address(b), r.eid);
                assertEq(receiveLibrary, c.receiveLib);
                assertFalse(usesDefault);
                // Minimal PR keeps the inherited executor configuration; validate it on every route.
                (uint32 maxMessageSize, address executor) = IUlnFork(c.sendLib).getExecutorConfig(address(b), r.eid);
                assertGe(maxMessageSize, 64);
                assertEq(executor, c.executor);
                UlnConfig memory send = IUlnFork(c.sendLib).getUlnConfig(address(b), r.eid);
                UlnConfig memory receive_ = IUlnFork(c.receiveLib).getUlnConfig(address(b), r.eid);
                assertEq(send.confirmations, c.confirmations);
                assertEq(receive_.confirmations, r.confirmations);
                assertEq(send.requiredDVNCount, 3);
                assertEq(receive_.requiredDVNCount, 3);
                assertEq(send.optionalDVNCount, 0);
                assertEq(receive_.optionalDVNCount, 0);
                assertEq(send.optionalDVNThreshold, 0);
                assertEq(receive_.optionalDVNThreshold, 0);
                // Effective zero alone would also pass when inheriting empty defaults.
                // Check the stored NIL sentinel to prove optional DVNs are explicitly disabled.
                assertEq(IUlnFork(c.sendLib).getAppUlnConfig(address(b), r.eid).optionalDVNCount, type(uint8).max);
                assertEq(IUlnFork(c.receiveLib).getAppUlnConfig(address(b), r.eid).optionalDVNCount, type(uint8).max);
                for (uint256 k; k < 3; ++k) {
                    assertGt(c.dvns[k].code.length, 0);
                    bool found;
                    bool received;
                    for (uint256 m; m < 3; ++m) {
                        if (send.requiredDVNs[m] == c.dvns[k]) found = true;
                        if (receive_.requiredDVNs[m] == c.dvns[k]) received = true;
                    }
                    assertTrue(found && received, "Wrong send/receive DVN");
                }
            }
        }
    }

    function test_allSixRoutes_quoteBurnVerifyCommitDeliver() public {
        for (uint256 i; i < 3; ++i) {
            for (uint256 j; j < 3; ++j) {
                if (i == j) continue;
                uint256 amount = 0.001 ether;
                Message memory m = _send(i, j, amount);
                vm.selectFork(forks[j]);
                Plan.Chain memory dst = Plan.chain(j);
                uint256 before_ = IERC20(dst.token).balanceOf(USER);
                uint256 lockboxBefore = dst.lockbox == address(0) ? 0 : IERC20(dst.token).balanceOf(dst.lockbox);
                _attest(m, j, 3, Plan.chain(i).confirmations);
                IUlnFork(dst.receiveLib).commitVerification(m.header, m.payloadHash);
                _deliver(m);
                assertEq(IERC20(dst.token).balanceOf(USER), before_ + amount);
                if (dst.lockbox != address(0)) {
                    assertEq(IERC20(dst.token).balanceOf(dst.lockbox), lockboxBefore - amount);
                }
                uint256 beforeReplay = IERC20(dst.token).balanceOf(USER);
                vm.expectRevert();
                ILayerZeroEndpointV2(Plan.ENDPOINT).lzReceive(m.origin, m.receiver, m.guid, m.payload, "");
                assertEq(IERC20(dst.token).balanceOf(USER), beforeReplay);
                console.log("Delivered source/destination:", Plan.chain(i).chainId, dst.chainId);
            }
        }
    }

    function test_threeOfThreeRequiredAndConfirmationsEnforced() public {
        Message memory m = _send(2, 0, 0.001 ether);
        vm.selectFork(forks[0]);
        Plan.Chain memory c = Plan.chain(0);
        _attest(m, 0, 1, 300);
        vm.expectRevert();
        IUlnFork(c.receiveLib).commitVerification(m.header, m.payloadHash);
        _attest(m, 0, 2, 300);
        vm.expectRevert();
        IUlnFork(c.receiveLib).commitVerification(m.header, m.payloadHash);
        vm.prank(c.dvns[2]);
        IUlnFork(c.receiveLib).verify(m.header, m.payloadHash, 299);
        vm.expectRevert();
        IUlnFork(c.receiveLib).commitVerification(m.header, m.payloadHash);
        vm.prank(c.dvns[2]);
        IUlnFork(c.receiveLib).verify(m.header, m.payloadHash, 300);
        IUlnFork(c.receiveLib).commitVerification(m.header, m.payloadHash);
        _deliver(m);
    }

    function _send(uint256 srcIndex, uint256 dstIndex, uint256 amount) internal returns (Message memory m) {
        vm.selectFork(forks[srcIndex]);
        Plan.Chain memory c = Plan.chain(srcIndex);
        Plan.Chain memory dst = Plan.chain(dstIndex);
        LayerZeroBridgeV2 b = LayerZeroBridgeV2(Plan.predicted(c));
        uint256 before_ = IERC20(c.token).balanceOf(USER);
        uint256 collateral = c.lockbox == address(0) ? 0 : IERC20(c.token).balanceOf(c.lockbox);
        uint256 fee = b.bridgeCost(dst.chainId, amount, USER);
        assertGt(fee, 0);
        vm.recordLogs();
        vm.prank(USER);
        b.bridge{value: fee}(dst.chainId, amount, USER);
        assertEq(IERC20(c.token).balanceOf(USER), before_ - amount);
        if (c.lockbox != address(0)) assertEq(IERC20(c.token).balanceOf(c.lockbox), collateral + amount);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == Plan.ENDPOINT && logs[i].topics[0] == keccak256("PacketSent(bytes,bytes,address)")) {
                (bytes memory packet, bytes memory opts, address sendLib) =
                    abi.decode(logs[i].data, (bytes, bytes, address));
                assertEq(opts, Plan.options());
                assertEq(sendLib, c.sendLib);
                m = this.decodePacket(packet);
                found = true;
            }
        }
        assertTrue(found, "No real PacketSent event");
        assertEq(m.receiver, Plan.predicted(dst));
        // Block progression here is local-only. Real DVN RPC observation/finality is not simulated.
        vm.roll(block.number + c.confirmations);
        console.log("Native fee chain/destination/wei:", c.chainId, dst.chainId, fee);
    }

    function decodePacket(bytes calldata packet) external pure returns (Message memory m) {
        m.header = packet.header();
        m.payload = packet.message();
        m.guid = packet.guid();
        m.payloadHash = keccak256(abi.encodePacked(m.guid, m.payload));
        m.origin = Origin(packet.srcEid(), packet.sender(), packet.nonce());
        m.receiver = packet.receiverB20();
    }

    function _attest(Message memory m, uint256 dstIndex, uint256 count, uint64 confirmations) internal {
        Plan.Chain memory c = Plan.chain(dstIndex);
        for (uint256 i; i < count; ++i) {
            // Explicit simulation boundary: impersonate each DVN at the deployed receive library.
            // Does not prove its off-chain service, signer quorum, allowlist or finality policy will attest.
            vm.prank(c.dvns[i]);
            IUlnFork(c.receiveLib).verify(m.header, m.payloadHash, confirmations);
        }
    }

    function _deliver(Message memory m) internal {
        vm.prank(RELAYER);
        ILayerZeroEndpointV2(Plan.ENDPOINT).lzReceive{gas: 300_000}(m.origin, m.receiver, m.guid, m.payload, "");
    }
}

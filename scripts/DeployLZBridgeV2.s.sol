// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {LayerZeroBridge} from "../contracts/bridgeToken/adapters/layerzero/LayerZeroBridgeV2.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IXERC20} from "../contracts/bridgeToken/interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol";

// ─── CreateX ────────────────────────────────────────────────────────────────
interface ICreateX {
    struct Values {
        uint256 constructorAmount;
        uint256 initCallAmount;
    }
    function deployCreate3(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
    function computeCreate3Address(bytes32 salt, address deployer) external pure returns (address computedAddress);
}

// ─── LZ V2 Endpoint ─────────────────────────────────────────────────────────
interface IEndpointV2 {
    struct SetConfigParam {
        uint32 eid;
        uint32 configType;
        bytes config;
    }
    function setConfig(address oapp, address lib, SetConfigParam[] calldata params) external;
    function setSendLibrary(address oapp, uint32 eid, address sendLib) external;
    function setReceiveLibrary(address oapp, uint32 eid, address receiveLib, uint256 gracePeriod) external;
}

// ─── ULN302 config ──────────────────────────────────────────────────────────
// configType = 2 for ULN302 (both send and receive)
struct UlnConfig {
    uint64 confirmations;
    uint8 requiredDVNCount;
    uint8 optionalDVNCount;
    uint8 optionalDVNThreshold;
    address[] requiredDVNs;  // must be sorted ascending, no duplicates
    address[] optionalDVNs;  // must be sorted ascending, no duplicates
}

contract DeployLZBridgeV2 is Script {

    // ─── CreateX (same address on all chains) ───────────────────────────────
    ICreateX constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    // ─── LZ V2 Endpoint (same address on all EVM chains) ───────────────────
    address constant LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 constant CONFIG_TYPE_ULN = 2;

    // ─── Endpoint IDs ───────────────────────────────────────────────────────
    uint32 constant ETH_EID  = 30101;
    uint32 constant BASE_EID = 30184;
    uint32 constant OP_EID   = 30111;

    // ─── Chain IDs ──────────────────────────────────────────────────────────
    uint256 constant ETH_CHAIN_ID  = 1;
    uint256 constant BASE_CHAIN_ID = 8453;
    uint256 constant OP_CHAIN_ID   = 10;

    // ─── Salt (same salt = same address on all chains via CREATE3) ──────────
    bytes32 constant SALT = keccak256("beefy.lz.bridge.v2.1");

    // ─── LZ executor options: ExecutorLzReceiveOption(gas=300_000, value=0) ─
    // Generated via: Options.newOptions().addExecutorLzReceiveOption(300_000, 0)
    bytes constant LZ_OPTIONS = hex"00030100110100000000000000000000000493e000";

    // ─── Per-chain config ────────────────────────────────────────────────────
    struct ChainConfig {
        // multisig owner for this chain (receives ownership + delegate after deploy)
        address msig;
        // tokens
        address bifi;
        address xbifi;
        address lockbox;
        // LZ message libs
        address sendLib;
        address receiveLib;
        // 3 required DVNs: LZ Labs + Google Cloud + Nethermind
        // Verify all addresses at: https://layerzeroscan.com/tools/defaults?version=V2
        address dvnLZ;
        address dvnGoogle;
        address dvnNethermind;
        // block confirmations for the ULN
        uint64 confirmations;
        // remote chains this bridge connects to
        uint32[] remoteEids;
        uint256[] remoteChainIds;
    }

    function getConfig() internal view returns (ChainConfig memory cfg) {
        if (block.chainid == ETH_CHAIN_ID) {
            cfg.msig          = vm.envAddress("MSIG");
            cfg.bifi          = vm.envAddress("BIFI");
            cfg.xbifi         = vm.envAddress("XBIFI");
            cfg.lockbox       = vm.envAddress("LOCKBOX");
            // Verify all at: https://layerzeroscan.com/tools/defaults?version=V2
            cfg.sendLib       = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
            cfg.receiveLib    = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
            cfg.dvnLZ         = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
            cfg.dvnGoogle     = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
            cfg.dvnNethermind = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;
            cfg.confirmations = 15;
            cfg.remoteEids      = new uint32[](2);
            cfg.remoteChainIds  = new uint256[](2);
            (cfg.remoteEids[0], cfg.remoteChainIds[0]) = (BASE_EID,  BASE_CHAIN_ID);
            (cfg.remoteEids[1], cfg.remoteChainIds[1]) = (OP_EID,    OP_CHAIN_ID);

        } else if (block.chainid == BASE_CHAIN_ID) {
            cfg.msig          = vm.envAddress("MSIG");
            cfg.bifi          = vm.envAddress("BIFI");
            cfg.xbifi         = vm.envAddress("XBIFI");
            cfg.lockbox       = vm.envAddress("LOCKBOX");
            cfg.sendLib       = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
            cfg.receiveLib    = 0xc70AB6f32772f59fBfc23889Ee5b66b7d18a3e7;
            cfg.dvnLZ         = 0xcd37CA043f8479064e10635020c65FfC005d36f;
            cfg.dvnGoogle     = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
            cfg.dvnNethermind = 0xcb566e3B6934Fa77258d68ea18055BCbb3d36BBf;
            cfg.confirmations = 10;
            cfg.remoteEids      = new uint32[](2);
            cfg.remoteChainIds  = new uint256[](2);
            (cfg.remoteEids[0], cfg.remoteChainIds[0]) = (ETH_EID,   ETH_CHAIN_ID);
            (cfg.remoteEids[1], cfg.remoteChainIds[1]) = (OP_EID,    OP_CHAIN_ID);

        } else if (block.chainid == OP_CHAIN_ID) {
            cfg.msig          = vm.envAddress("MSIG");
            cfg.bifi          = vm.envAddress("BIFI");
            cfg.xbifi         = vm.envAddress("XBIFI");
            cfg.lockbox       = vm.envAddress("LOCKBOX");
            cfg.sendLib       = 0x1322871e4ab09Bc7f5717189434f97bBD9546e95;
            cfg.receiveLib    = 0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063;
            cfg.dvnLZ         = 0x6A02D83e8d433304bba74EF1c427913958187142;
            cfg.dvnGoogle     = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
            cfg.dvnNethermind = 0xa7b5189bcA84Cd304D8553977c7C614329750d99;
            cfg.confirmations = 10;
            cfg.remoteEids      = new uint32[](2);
            cfg.remoteChainIds  = new uint256[](2);
            (cfg.remoteEids[0], cfg.remoteChainIds[0]) = (ETH_EID,   ETH_CHAIN_ID);
            (cfg.remoteEids[1], cfg.remoteChainIds[1]) = (BASE_EID,  BASE_CHAIN_ID);

        } else {
            revert("DeployLZBridgeV2: unsupported chain");
        }
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        ChainConfig memory cfg = getConfig();

        // ── Pre-compute address ──────────────────────────────────────────────
        address predicted = CREATEX.computeCreate3Address(SALT, deployer);
        console.log("Predicted bridge address:", predicted);

        vm.startBroadcast(deployerKey);

        // ── 1. Deploy via CreateX (CREATE3 = same address on every chain) ───
        bytes memory constructorArgs = abi.encode(LZ_ENDPOINT);
        bytes memory initCode = abi.encodePacked(
            type(LayerZeroBridge).creationCode,
            constructorArgs
        );
        address bridgeAddr = CREATEX.deployCreate3(SALT, initCode);
        require(bridgeAddr == predicted, "address mismatch");
        console.log("Bridge deployed at:", bridgeAddr);

        LayerZeroBridge bridge = LayerZeroBridge(bridgeAddr);

        // ── 2. Initialize ────────────────────────────────────────────────────
        // Delegate is set to deployer here so this script can call setConfig,
        // setSendLibrary, setReceiveLibrary below. Handed off to msig at the end.
        bridge.initialize(
            IERC20(cfg.bifi),
            IXERC20(cfg.xbifi),
            IXERC20Lockbox(cfg.lockbox),
            deployer
        );
        console.log("Bridge initialized");

        // ── 3. Set LZ executor options ───────────────────────────────────────
        bridge.setOptions(LZ_OPTIONS);
        console.log("Options set");

        // ── 4. Add chain ID <-> EID mappings ─────────────────────────────────
        bridge.addChainIds(cfg.remoteChainIds, cfg.remoteEids);
        console.log("Chain IDs mapped");

        // ── 5. Set peers (same address on every chain thanks to CREATE3) ─────
        for (uint i; i < cfg.remoteEids.length; ++i) {
            bridge.setPeer(cfg.remoteEids[i], bytes32(uint256(uint160(predicted))));
        }
        console.log("Peers set");

        // ── 6. Wire message libraries and DVN config ─────────────────────────
        IEndpointV2 endpoint = IEndpointV2(LZ_ENDPOINT);

        // Build sorted DVN array — ULN302 requires addresses in ascending order
        address[] memory requiredDVNs = _sortThree(
            cfg.dvnLZ,
            cfg.dvnGoogle,
            cfg.dvnNethermind
        );

        for (uint i; i < cfg.remoteEids.length; ++i) {
            uint32 remoteEid = cfg.remoteEids[i];

            // 6a. Override send + receive libs
            endpoint.setSendLibrary(bridgeAddr, remoteEid, cfg.sendLib);
            endpoint.setReceiveLibrary(bridgeAddr, remoteEid, cfg.receiveLib, 0);

            // 6b. ULN config — same requirements applied to both send and receive
            UlnConfig memory uln = UlnConfig({
                confirmations:        cfg.confirmations,
                requiredDVNCount:     3,
                optionalDVNCount:     0,
                optionalDVNThreshold: 0,
                requiredDVNs:         requiredDVNs,
                optionalDVNs:         new address[](0)
            });
            bytes memory ulnEncoded = abi.encode(uln);

            IEndpointV2.SetConfigParam[] memory params = new IEndpointV2.SetConfigParam[](1);
            params[0] = IEndpointV2.SetConfigParam({
                eid:        remoteEid,
                configType: CONFIG_TYPE_ULN,
                config:     ulnEncoded
            });

            endpoint.setConfig(bridgeAddr, cfg.sendLib,    params);
            endpoint.setConfig(bridgeAddr, cfg.receiveLib, params);

            console.log("Config set for remote EID:", remoteEid);
        }

        // ── 7. Hand off delegate + ownership to msig ─────────────────────────
        // setDelegate updates the endpoint's delegate (controls setConfig etc.)
        bridge.setDelegate(cfg.msig);
        // transferOwnership hands over onlyOwner functions (setPeer, setOptions…)
        bridge.transferOwnership(cfg.msig);
        console.log("Ownership + delegate transferred to msig:", cfg.msig);

        vm.stopBroadcast();

        console.log("=== Deployment complete ===");
        console.log("Bridge:   ", bridgeAddr);
        console.log("Owner/delegate:", cfg.msig);
        console.log("Chain ID: ", block.chainid);
    }

    // ─── Helpers ────────────────────────────────────────────────────────────
    function _sortThree(address a, address b, address c) internal pure returns (address[] memory s) {
        s = new address[](3);
        // Simple 3-element insertion sort
        s[0] = a; s[1] = b; s[2] = c;
        if (s[0] > s[1]) (s[0], s[1]) = (s[1], s[0]);
        if (s[1] > s[2]) (s[1], s[2]) = (s[2], s[1]);
        if (s[0] > s[1]) (s[0], s[1]) = (s[1], s[0]);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Test-only expected chain state and timelock activation calldata.
library MinimalForkPlan {
    address internal constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    address internal constant DEPLOYER = 0x6CfE163eaf9aB5ae485f4c381E819a07B2b5566e;
    address internal constant ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal constant KEEPER = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    address internal constant OLD_BRIDGE = 0xdddaEc9c267dF24aD66Edc3B2cBe25dB86422051;
    address internal constant AXELAR = 0xaaa6A279fC98b9bF94bD479C90D701417e361fc2;
    uint256 internal constant CANARY_LIMIT = 1 ether;
    uint256 internal constant RECEIVE_GAS = 300_000;
    uint256 internal constant DELAY = 1 days;

    struct Chain {
        uint256 chainId;
        uint32 eid;
        uint64 confirmations;
        uint256 blockNumber;
        address safe;
        address manager;
        address timelock;
        address token;
        address xToken;
        address lockbox;
        address sendLib;
        address receiveLib;
        address executor;
        address[3] dvns;
    }

    function chain(uint256 index) internal pure returns (Chain memory c) {
        c.dvns[1] = 0xD56e4eAb23cb81f43168F9F45211Eb027b9aC7cc;
        if (index == 0) {
            c.chainId = 1;
            c.eid = 30101;
            c.confirmations = 15;
            c.blockNumber = 26356493;
            c.safe = 0x34fEf5DA92c59d6aC21d0A75ce90B351D0Fb6CE6;
            c.manager = 0x23B4a2b256AD52b7C2FCcAFba0Fd96e1E1886F71;
            c.timelock = 0xFD5D54dB16A514951C5DB740B5780C9A75ddf87B;
            c.token = 0xBEEF8e0982874e0292E6C5751C5A4092b3e1BEEF;
            c.xToken = 0xb1feA302f3B2E93FA04E46dCCE35F2Fc522d7bB9;
            c.lockbox = 0xc6e3d0CAF52E057Fb8950ae9d07aE67602919AcD;
            c.sendLib = 0xbB2Ea70C9E858123480642Cf96acbcCE1372dCe1;
            c.receiveLib = 0xc02Ab410f0734EFa3F14628780e6e695156024C2;
            c.executor = 0x173272739Bd7Aa6e4e214714048a9fE699453059;
            c.dvns[0] = 0x589dEDbD617e0CBcB916A9223F4d1300c294236b;
            c.dvns[2] = 0xa59BA433ac34D2927232918Ef5B2eaAfcF130BA5;
        } else if (index == 1) {
            c.chainId = 10;
            c.eid = 30111;
            c.confirmations = 15;
            c.blockNumber = 159188782;
            c.safe = 0x2c572743B345ED750907dC95D459dbeaC499D8CF;
            c.manager = 0x82FbDEb4a265dE010f15DfB4F17e21940B7B7470;
            c.timelock = 0x9C1E1C57ff38E154200bfCd9810eC653DaBb6Bd5;
            c.token = 0xc55E93C62874D8100dBd2DfE307EDc1036ad5434;
            c.xToken = c.token;
            c.sendLib = 0x1322871e4ab09Bc7f5717189434f97bBD9546e95;
            c.receiveLib = 0x3c4962Ff6258dcfCafD23a814237B7d6Eb712063;
            c.executor = 0x2D2ea0697bdbede3F01553D2Ae4B8d0c486B666e;
            c.dvns[0] = 0x6A02D83e8d433304bba74EF1c427913958187142;
            c.dvns[2] = 0xa7b5189bcA84Cd304D8553977c7C614329750d99;
        } else {
            require(index == 2, "Unsupported chain");
            c.chainId = 8453;
            c.eid = 30184;
            c.confirmations = 300;
            c.blockNumber = 53929830;
            c.safe = 0x6FfaCA7C3B38Ec2d631D86e15f328ee6eF6C6226;
            c.manager = 0xEFF32d64e6fB389feb5e9d76C7F1388f0eC0F29B;
            c.timelock = 0xE31Ad18173155bd7CCAc30880171fD4662D383fd;
            c.token = 0xc55E93C62874D8100dBd2DfE307EDc1036ad5434;
            c.xToken = c.token;
            c.sendLib = 0xB5320B0B3a13cC860893E2Bd79FCd7e13484Dda2;
            c.receiveLib = 0xc70AB6f32772f59fBfc23889Caf4Ba3376C84bAf;
            c.executor = 0x2CCA08ae69E0C44b18a57Ab2A87644234dAebaE4;
            c.dvns[0] = 0x9e059a54699a285714207b43B055483E78FAac25;
            c.dvns[2] = 0xcd37CA043f8479064e10635020c65FfC005d36f6;
        }
    }

    function salt(Chain memory) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(DEPLOYER)) << 96) | uint88(bytes11(keccak256("beefy.lz.bridge.v2.2"))));
    }

    function predicted(Chain memory c) internal pure returns (address) {
        bytes32 guarded = keccak256(abi.encode(bytes32(uint256(uint160(DEPLOYER))), salt(c)));
        address proxy = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            CREATEX,
                            guarded,
                            hex"21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f"
                        )
                    )
                )
            )
        );
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }

    function options() internal pure returns (bytes memory) {
        // Type 3, worker 1, option size 17, receive option 1, uint128 gas.
        return abi.encodePacked(uint16(3), uint8(1), uint16(17), uint8(1), uint128(RECEIVE_GAS));
    }

    function limitsData(Chain memory c, uint256 mintLimit, uint256 burnLimit) internal pure returns (bytes memory) {
        address[] memory adapters = new address[](1);
        uint256[] memory mintLimits = new uint256[](1);
        uint256[] memory burnLimits = new uint256[](1);
        adapters[0] = predicted(c);
        mintLimits[0] = mintLimit;
        burnLimits[0] = burnLimit;
        return abi.encodeWithSignature("setLimits(address[],uint256[],uint256[])", adapters, mintLimits, burnLimits);
    }

    function operationSalt(Chain memory c, uint256 mintLimit, uint256 burnLimit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode("moobifi-lzv2-activation-v1", c.chainId, predicted(c), mintLimit, burnLimit, uint256(0))
        );
    }

    function schedule(Chain memory c, uint256 mintLimit, uint256 burnLimit) internal pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
            c.manager,
            0,
            limitsData(c, mintLimit, burnLimit),
            bytes32(0),
            operationSalt(c, mintLimit, burnLimit),
            DELAY
        );
    }

    function execute(Chain memory c, uint256 mintLimit, uint256 burnLimit) internal pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "execute(address,uint256,bytes,bytes32,bytes32)",
            c.manager,
            0,
            limitsData(c, mintLimit, burnLimit),
            bytes32(0),
            operationSalt(c, mintLimit, burnLimit)
        );
    }
}

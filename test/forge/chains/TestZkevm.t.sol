pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {BeefyRevenueBridgeStructs} from "../../../contracts/bridge/BeefyRevenueBridgeStructs.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestZkEvm is Test, BeefyRevenueBridgeStructs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xA8CE8aee21bC2A48a5EF670afCc9274C7bbbC035);
    IERC20 constant native = IERC20(0x4F9A0e7FD2Bf6067db6994CF12E4495Df938E6e9);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "zkEVM";
    string swap = "ALGEBRA";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe;
    address router = 0xF6Ad3CcF71Abb3E12beCf6b3D2a74C963859ADCd;

    function setUp() public {
        bridge = new BeefyRevenueBridge();
        initContract();
    }

    function initContract() public {
        bridge.initialize(
            stable, 
            native
        );

        DestinationAddress memory destinationAddress = DestinationAddress(0x161D61e30284A33Ab1ed227beDcac6014877B3DE, "0x161D61e30284A33Ab1ed227beDcac6014877B3DE", "0x161D61e30284A33Ab1ed227beDcac6014877B3DE");
        bridge.setDestinationAddress(destinationAddress);
    }

    function test_ZkEvmBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);

        bytes memory data = abi.encode("0x");
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        
        vm.startPrank(user);
        deal(address(native), address(bridge), 10 ether);
        bridge.harvest();
        vm.stopPrank();
    }

    function setUpSwap() public {
        bytes32 swapHash = bridge.findHash(swap);

        address[] memory tokens = new address[](2);
        tokens[0] = address(native);
        tokens[1] = address(stable);

        bytes memory data = abi.encode(tokens);

        SwapParams memory swapParams = SwapParams(router, data);
        bridge.setActiveSwap(swapHash, swapParams);

        // We have allowance for router to spend our native. 
        uint256 approvedAmount = native.allowance(address(bridge), router);
        assertEq(approvedAmount, type(uint256).max);
    }

    // Convert token route to encoded path
    // uint24 type for fees so path is packed tightly
    function routeToPath(
        address[] memory _route,
        uint24[] memory _fee
    ) internal pure returns (bytes memory path) {
        path = abi.encodePacked(_route[0]);
        uint256 feeLength = _fee.length;
        for (uint256 i = 0; i < feeLength; i++) {
            path = abi.encodePacked(path, _fee[i], _route[i+1]);
        }
    }
}
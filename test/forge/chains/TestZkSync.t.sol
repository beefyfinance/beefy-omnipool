pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestZkSync is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0x3355df6D4c9C3035724Fd0e3914dE96A5a83aaf4);
    IERC20 constant native = IERC20(0x5AEa5775959fBC2557Cc8789bC1bf90A239D9a91);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "zkSYNC";
    string swap = "SOLIDLY";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x11f943b2c77b743AB90f4A0Ae7d5A4e7FCA3E102;
    address router = 0x46dbd39e26a56778d88507d7aEC6967108C0BD36;

    function setUp() public {
        bridge = new BeefyRevenueBridge();
        initContract();
    }

    function initContract() public {
        bridge.initialize();

        bridge.setStable(stable, native);

        DestinationAddress memory destinationAddress = DestinationAddress(0x161D61e30284A33Ab1ed227beDcac6014877B3DE, "0x161D61e30284A33Ab1ed227beDcac6014877B3DE", "0x161D61e30284A33Ab1ed227beDcac6014877B3DE");
        bridge.setDestinationAddress(destinationAddress);
    }

    function test_zkSyncBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);
        bytes memory data = abi.encode("");
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        
        vm.startPrank(user);
        deal(address(native), address(bridge), 10 ether);
        console.log(10);
        bridge.harvest();
        vm.stopPrank();
    }

    function setUpSwap() public {
        bytes32 swapHash = bridge.findHash("SOLIDLY");

        ISolidlyRouter.Routes[] memory route = new ISolidlyRouter.Routes[](1);
        route[0] = ISolidlyRouter.Routes(address(native), address(stable), false);

        bytes memory data = abi.encode(route);

        SwapParams memory swapParams = SwapParams(router, data);
        bridge.setActiveSwap(swapHash, swapParams);

        // We have allowance for router to spend our native. 
        uint256 approvedAmount = native.allowance(address(bridge), router);
        assertEq(approvedAmount, type(uint256).max);
    }
}
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestKava is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xEB466342C4d449BC9f53A865D5Cb90586f405215);
    IERC20 constant native = IERC20(0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "AXELAR";
    string swap = "SOLIDLY";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0xe432150cce91c13a887f7D836923d5597adD8E31;
    address router = 0xA7544C409d772944017BB95B99484B6E0d7B6388;

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

    function test_AxelarBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);
        Axelar memory axelarParams = Axelar("Polygon", "axlUSDC");
        bytes memory data = abi.encode(axelarParams);
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        
        vm.startPrank(user);
        deal(address(native), address(bridge), 10 ether);
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

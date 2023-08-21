pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {BeefyRevenueBridgeStructs} from "../../../contracts/bridge/BeefyRevenueBridgeStructs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestFantom is Test, BeefyRevenueBridgeStructs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0x1B6382DBDEa11d97f24495C9A90b7c88469134a4);
    IERC20 constant native = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "AXELAR";
    string swap = "UNISWAP_V2";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x304acf330bbE08d1e512eefaa92F6a57871fD895;
    address router = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;

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
        bytes32 swapHash = bridge.findHash(swap);

        address[] memory route = new address[](2);
        route[0] = address(native);
        route[1] = address(stable);

        bytes memory data = abi.encode(route);

        SwapParams memory swapParams = SwapParams(router, data);
        bridge.setActiveSwap(swapHash, swapParams);

        // We have allowance for router to spend our native. 
        uint256 approvedAmount = native.allowance(address(bridge), router);
        assertEq(approvedAmount, type(uint256).max);
    }
}

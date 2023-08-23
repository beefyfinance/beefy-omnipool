pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestCronos is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xc21223249CA28397B4B6541dfFaEcC539BfF0c59);
    IERC20 constant native = IERC20(0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "SYNAPSE";
    string swap = "UNISWAP_V2";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x991adb00eF4c4a6D1eA6036811138Db4379377C2;
    address router = 0x145863Eb42Cf62847A6Ca784e6416C1682b1b2Ae;

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

    function test_SynapseBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);
        Synapse memory synapseParams = Synapse(
            137,
            1,
            0,
            0x396c9c192dd323995346632581BEF92a31AC623b,
            0,
            2
        );
        bytes memory data = abi.encode(synapseParams);
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

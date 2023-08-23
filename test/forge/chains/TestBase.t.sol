pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestBase is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA);
    IERC20 constant native = IERC20(0x4200000000000000000000000000000000000006);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "STARGATE";
    string swap = "UNISWAP_V3";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x45f1A95A4D3f3836523F5c83673c797f4d4d263B;
    address router = 0x2626664c2603336E57B271c5C0b26F421741e481;

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

    function test_StargateBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);

        Stargate memory stargate = Stargate(110, 1500000, 1, 1);
        bytes memory data = abi.encode(stargate);
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

        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;

        bytes memory path = routeToPath(tokens, fees);
        bytes memory data = abi.encode(path);

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
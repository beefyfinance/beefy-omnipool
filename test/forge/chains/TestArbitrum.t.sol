pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {BeefyRevenueBridgeStructs} from "../../../contracts/bridge/BeefyRevenueBridgeStructs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestArbitrum is Test, BeefyRevenueBridgeStructs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 constant native = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "CIRCLE";
    string swap = "UNISWAP_V3_DEADLINE";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x19330d10D9Cc8751218eaf51E8885D058642E08A;
    address router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

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

    function test_CircleBridge() public {
        bytes32 bridgeHash = bridge.findHash(activeBridge);
        uint32 destinationDomain = 0;
        bytes memory data = abi.encode(destinationDomain);
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        
        vm.startPrank(user);
        deal(address(native), address(bridge), 10 ether);
        uint256 bal = native.balanceOf(address(bridge));
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
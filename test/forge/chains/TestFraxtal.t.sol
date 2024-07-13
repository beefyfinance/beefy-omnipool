pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestFraxtal is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xFc00000000000000000000000000000000000001);
    IERC20 constant native = IERC20(0xFC00000000000000000000000000000000000006);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "FRAXFERRY";
    string swap = "UNISWAP_V3_DEADLINE";
    bytes32 active =  keccak256(abi.encode("FRAXFERRY"));
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x00160baF84b3D2014837cc12e838ea399f8b8478;
    address router = 0xAAAE99091Fbb28D400029052821653C1C752483B;

    function setUp() public {
        bridge = BeefyRevenueBridge(payable(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B));
        initContract();
    }

    function initContract() public {
       // bridge.initialize();

      //  bridge.setStable(stable, native);
        vm.startPrank(user);
        DestinationAddress memory destinationAddress = DestinationAddress(0x340014C66D49f50c48E6eF0D02aB630F246F1921, "0x340014C66D49f50c48E6eF0D02aB630F246F1921", "0x340014C66D49f50c48E6eF0D02aB630F246F1921");
        bridge.setDestinationAddress(destinationAddress);
        
        BeefyRevenueBridge newImplementation = new BeefyRevenueBridge();
        bridge.upgradeTo(address(newImplementation));

        console.logBytes32(active);
        bridge.setBridgeMap(active, "bridgeFraxFerry()");
      
        vm.stopPrank();
    }

    function test_fraxtalBridge() public {
        vm.startPrank(user);
        bytes memory data = abi.encode("0x");
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(active, bridgeParams);

        setUpSwap();
       // deal(address(native), address(bridge), 10 ether);
        bridge.harvest();
        vm.stopPrank();
    }

    function setUpSwap() public {
        bytes32 swapHash = bridge.findHash(swap);

        address[] memory tokens = new address[](2);
        tokens[0] = address(native);
        tokens[1] = address(stable);

        uint24[] memory fees = new uint24[](1);
        fees[0] = 250;

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
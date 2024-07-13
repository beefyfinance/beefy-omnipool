pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestLinea is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
    IERC20 constant native = IERC20(0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "LINEA";
    string swap = "ALGEBRA";
    bytes32 active =  keccak256(abi.encode("LINEA"));
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0xA2Ee6Fce4ACB62D95448729cDb781e3BEb62504A;
    address router = 0x3921e8cb45B17fC029A0a6dE958330ca4e583390;

    function setUp() public {
        bridge = BeefyRevenueBridge(payable(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B));
        initContract();
    }

    function initContract() public {
       // bridge.initialize();

      //  bridge.setStable(stable, native);
        vm.startPrank(user);
        DestinationAddress memory destinationAddress = DestinationAddress(0x65f2145693bE3E75B8cfB2E318A3a74D057e6c7B, "0x65f2145693bE3E75B8cfB2E318A3a74D057e6c7B", "0x65f2145693bE3E75B8cfB2E318A3a74D057e6c7B");
        bridge.setDestinationAddress(destinationAddress);
        
        BeefyRevenueBridge newImplementation = new BeefyRevenueBridge();
        bridge.upgradeTo(address(newImplementation));

        console.logBytes32(active);
        bridge.setBridgeMap(active, "bridgeLinea()");
      
        vm.stopPrank();
    }

    function test_lineaBridge() public {
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
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestMode is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xd988097fb8612cc24eeC14542bC03424c656005f);
    IERC20 constant native = IERC20(0x4200000000000000000000000000000000000006);

    BeefyRevenueBridge bridge;
    Cowllector cowllector;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "ACROSS";
    bytes32 active =  keccak256(abi.encode("ACROSS"));
    string swap = "ALGEBRA";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0x3baD7AD0728f9917d1Bf08af5782dCbD516cDd96;
    address router = 0xAc48FcF1049668B285f3dC72483DF5Ae2162f7e8;

    function setUp() public {
        bridge = BeefyRevenueBridge(payable(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B));
        initContract();
    }

    function initContract() public {
        vm.startPrank(user);
        DestinationAddress memory destinationAddress = DestinationAddress(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B, "0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B", "0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B");
        bridge.setDestinationAddress(destinationAddress);
        
        BeefyRevenueBridge newImplementation = new BeefyRevenueBridge();
        bridge.upgradeTo(address(newImplementation));

        bridge.setStable(stable, native);

        console.logBytes32(active);
        bridge.setBridgeMap(active, "bridgeAcross()");
      
        vm.stopPrank();
    }

    function test_AcrossBridge() public {
        vm.startPrank(user);
        bytes32 bridgeHash = bridge.findHash(activeBridge);
        uint256 relayFee = 30000;
        uint256 destinationChainId = 42161;
        Across memory _across = Across(destinationChainId, relayFee);
        bytes memory data = abi.encode(_across);
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        
        bridge.harvest();
        vm.stopPrank();
    }

    function setUpSwap() public {
        bytes32 swapHash = bridge.findHash(swap);

        address[] memory tokens = new address[](2);
        tokens[0] = address(native);
        tokens[1] = address(stable);

        //bytes memory path = routeToPath(tokens);
        bytes memory data = abi.encode(tokens);

        SwapParams memory swapParams = SwapParams(router, data);
        bridge.setActiveSwap(swapHash, swapParams);

        // We have allowance for router to spend our native. 
        uint256 approvedAmount = native.allowance(address(bridge), router);
        assertEq(approvedAmount, type(uint256).max);
    }
}
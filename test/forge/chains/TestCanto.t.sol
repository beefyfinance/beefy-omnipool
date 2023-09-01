pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {ISolidlyRouter} from "../../../contracts/interfaces/swap/ISolidlyRouter.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestCanto is Test, Structs {
    using Path for bytes;

    IERC20 constant note = IERC20(0x80b5a32E4F032B2a058b4F29EC95EEfEEB87aDcd);
    IERC20 constant stable = IERC20(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503);
    IERC20 constant native = IERC20(0x826551890Dc65655a0Aceca109aB11AbDbD7a07B);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "SYNAPSE";
    string swap = "SOLIDLY";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0xe103ab2f922aa1a56EC058AbfDA2CeEa1e95bCd7;
    address router = 0xa252eEE9BDe830Ca4793F054B506587027825a8e;

    function setUp() public {
        bridge = BeefyRevenueBridge(payable(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B));
       // initContract();
    }

    function initContract() public {
        bridge.initialize();

        bridge.setStable(stable, native);

        DestinationAddress memory destinationAddress = DestinationAddress(0x161D61e30284A33Ab1ed227beDcac6014877B3DE, "0x161D61e30284A33Ab1ed227beDcac6014877B3DE", "0x161D61e30284A33Ab1ed227beDcac6014877B3DE");
        bridge.setDestinationAddress(destinationAddress);
    }

    function test_SynapseBridge() public {
      /*  bytes32 bridgeHash = bridge.findHash(activeBridge);
        Synapse memory synapseParams = Synapse(
            137,
            2,
            0,
            0xD8836aF2e565D3Befce7D906Af63ee45a57E8f80,
            0,
            2
        );
        bytes memory data = abi.encode(synapseParams);
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);
*/
     //   setUpSwap();
        
        vm.startPrank(user);
       // deal(address(native), address(bridge), 10 ether);
        bridge.harvest();
        vm.stopPrank();
    }

    function setUpSwap() public {
        bytes32 swapHash = bridge.findHash("SOLIDLY");

        ISolidlyRouter.Routes[] memory route = new ISolidlyRouter.Routes[](2);
        route[0] = ISolidlyRouter.Routes(address(native), address(note), false);
        route[1] = ISolidlyRouter.Routes(address(note), address(stable), true);

        bytes memory data = abi.encode(route);

        SwapParams memory swapParams = SwapParams(router, data);
        bridge.setActiveSwap(swapHash, swapParams);

        // We have allowance for router to spend our native. 
        uint256 approvedAmount = native.allowance(address(bridge), router);
        assertEq(approvedAmount, type(uint256).max);
    }
}

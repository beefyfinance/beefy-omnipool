pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyRevenueBridge} from "../../../contracts/bridge/BeefyRevenueBridge.sol";
import {Structs} from "../../../contracts/bridge/Structs.sol";
import {Path} from "../../../contracts/utils/Path.sol";

contract TestMetis is Test, Structs {
    using Path for bytes;

    IERC20 constant stable = IERC20(0xEA32A96608495e54156Ae48931A7c20f0dcc1a21);
    IERC20 constant native = IERC20(0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000);

    BeefyRevenueBridge bridge;

    address user = 0x161D61e30284A33Ab1ed227beDcac6014877B3DE;
    string activeBridge = "SYNAPSE";
    string swap = "UNISWAP_V2";
    bytes32 activeSwap = keccak256(abi.encode(swap));
    address activeBridgeAddress = 0xC35a456138dE0634357eb47Ba5E74AFE9faE9a98;
    address router = 0x1E876cCe41B7b844FDe09E38Fa1cf00f213bFf56;

    function setUp() public {
        bridge = BeefyRevenueBridge(payable(0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B));//new BeefyRevenueBridge();
        //initContract();
    }

    function initContract() public {
        bridge.initialize();

        bridge.setStable(stable, native);

        DestinationAddress memory destinationAddress = DestinationAddress(0x161D61e30284A33Ab1ed227beDcac6014877B3DE, "0x161D61e30284A33Ab1ed227beDcac6014877B3DE", "0x161D61e30284A33Ab1ed227beDcac6014877B3DE");
        bridge.setDestinationAddress(destinationAddress);
    }

     function test_SynapseBridge() public {
     /*   bytes32 bridgeHash = bridge.findHash(activeBridge);
        Synapse memory synapseParams = Synapse(
            137,
            1,
            0,
            0x961318Fc85475E125B99Cc9215f62679aE5200aB,
            0,
            2
        );
        bytes memory data = abi.encode(synapseParams);
        BridgeParams memory bridgeParams = BridgeParams(activeBridgeAddress, data);
        bridge.setActiveBridge(bridgeHash, bridgeParams);

        setUpSwap();
        */
        vm.startPrank(user);
       // deal(address(native), address(bridge), 10 ether);
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
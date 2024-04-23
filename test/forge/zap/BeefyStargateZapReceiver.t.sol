pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyStargateZapReceiver} from "../../../contracts/zap/stargate/BeefyStargateZapReceiver.sol";
import {IStargate} from "../../../contracts/interfaces/bridge/IStargate.sol";

contract BeefyStargateZapReceiverTest is Test {
    BeefyStargateZapReceiver zapReceiver;

    address constant STARGATE_ARB_COMPOSER = 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9;
    address constant ARB_WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant ARB_USDCE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant USER_ADDRESS = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    address constant ARB_VAULT_SILO_USDCE = 0x37CaF9ede3f8157163B17b46C794a7053401B296; // silo-usdce-arb
    address constant ARB_VAULT_SILO_ETH = 0x6a96e55c6a8ab9380E006D7C83232d3E7a935402; // silo-eth-ezeth
    uint16 constant STARGATE_ARB_CHAIN_ID = 110;
    uint16 constant STARGATE_OP_CHAIN_ID = 111;
    uint256 constant GAS_REQUIRED = 2_000_000;

    struct BridgeData {
        address vault;
        address token;
        address receiver;
    }

    error NotAuthorized();

    function setUp() public {
        zapReceiver = new BeefyStargateZapReceiver();
        zapReceiver.initialize(STARGATE_ARB_COMPOSER, ARB_WNATIVE);
    }

    function getDepositPayload(address _vault, address _token, address _user) internal pure returns (bytes memory) {
        BridgeData memory _bridgeData = BridgeData(_vault, _token, _user);
        return abi.encode(_bridgeData);
    }

    function getBridgeCost(uint16 _destChainId, uint256 _destGasRequired, bytes memory _payload) internal view returns (uint256) {
        IStargate composer = IStargate(zapReceiver.stargate());
        (uint256 gasCost,) = composer.quoteLayerZeroFee(
            _destChainId, // _chainId (destination)
            1, // _functionType (TYPE_SWAP_REMOTE)
            abi.encodePacked(address(zapReceiver)), // _toAddress
            _payload, // _transferAndCallPayload
            IStargate.lzTxObj(_destGasRequired, 0, "") // _lzTxParams
        );
        return gasCost;
    }

    function test_bridge_in_native() public {
        uint256 amount = 1 ether;

        vm.startPrank(address(STARGATE_ARB_COMPOSER));
        vm.deal(address(STARGATE_ARB_COMPOSER), amount);

        bytes memory payload = getDepositPayload(ARB_VAULT_SILO_ETH, ARB_WNATIVE, USER_ADDRESS);
        uint256 sharesBefore = IERC20(ARB_VAULT_SILO_ETH).balanceOf(USER_ADDRESS);

        zapReceiver.sgReceive{value: amount, gas: GAS_REQUIRED}(
            STARGATE_OP_CHAIN_ID,
            "",
            0,
            ARB_WNATIVE,
            0,
            payload
        );

        uint256 sharesReceived = IERC20(ARB_VAULT_SILO_ETH).balanceOf(USER_ADDRESS) - sharesBefore;
        assertNotEq(sharesReceived, 0, "Received no shares");

        vm.stopPrank();
    }

    function test_bridge_in_erc20() public {
        uint256 amount = 1000_000_000;

        vm.startPrank(address(STARGATE_ARB_COMPOSER));

        bytes memory payload = getDepositPayload(ARB_VAULT_SILO_USDCE, ARB_USDCE, USER_ADDRESS);
        uint256 sharesBefore = IERC20(ARB_VAULT_SILO_USDCE).balanceOf(USER_ADDRESS);

        deal(address(ARB_USDCE), address(zapReceiver), amount);
        zapReceiver.sgReceive{gas: GAS_REQUIRED}(
            STARGATE_OP_CHAIN_ID,
            "",
            0,
            ARB_USDCE,
            0,
            payload
        );

        uint256 sharesReceived = IERC20(ARB_VAULT_SILO_USDCE).balanceOf(USER_ADDRESS) - sharesBefore;
        assertNotEq(sharesReceived, 0, "Received no shares");

        vm.stopPrank();
    }

    function test_bridge_in_malicious() public {
        uint256 amount = 1000_000_000;

        vm.startPrank(address(USER_ADDRESS));

        bytes memory payload = getDepositPayload(ARB_VAULT_SILO_USDCE, ARB_USDCE, USER_ADDRESS);
        uint256 sharesBefore = IERC20(ARB_VAULT_SILO_USDCE).balanceOf(USER_ADDRESS);

        deal(address(ARB_USDCE), address(zapReceiver), amount);
        vm.expectRevert(NotAuthorized.selector);
        zapReceiver.sgReceive{gas: GAS_REQUIRED}(
            STARGATE_OP_CHAIN_ID,
            "",
            0,
            ARB_USDCE,
            0,
            payload
        );

        uint256 sharesReceived = IERC20(ARB_VAULT_SILO_USDCE).balanceOf(USER_ADDRESS) - sharesBefore;
        assertEq(sharesReceived, 0, "Received shares");

        vm.stopPrank();
    }
}
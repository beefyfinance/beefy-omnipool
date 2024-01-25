pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {BeefyStargateZap} from "../../../contracts/zap/stargate/BeefyStargateZap.sol";

contract BeefyStargateZapTest is Test {

    BeefyStargateZap bridge;
    address constant stargate = 0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9;
    address constant native = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdce = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant user = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    address constant mooSonneEth = 0x3f63e9Db070ADe3e833EF8972Ac5E9810367a49c;
    address constant mooSonneUsdce = 0xcAAeaa835332B5bdB54c1753f4334f53021df7ea;
    address constant mooSiloUsdce = 0x0da5EF5F02B8156a9a191d080369E420243C4501;
    address constant mooSiloEth = 0x6443ac40DcD204739b8127F1aaec53071bBca7DF;
    uint16 constant thisChainId = 110;
    uint16 constant opChainId = 111;
    uint256 constant realOpChainId = 10;

    uint16 constant usdcePoolId = 1;
    uint16 constant ethPoolId = 13;

    uint16[] chains;
    uint256[] gasLimits;


    struct BridgeData {
        address user;
        address token;
        address vault;
    }

    error InvalidVault();
    error InvalidToken();
    error InvalidChainId();
    error NotAuthorized();

    error NoMooTokensOnArrival();
    error NoFundsMoved();

    function setUp() public {
        chains.push(opChainId);
        gasLimits.push(2000000);

        address[] memory _tokens = new address[](2);
        _tokens[0] = native;
        _tokens[1] = usdce;

        address[] memory _vaults = new address[](2);
        _vaults[0] = mooSonneEth;
        _vaults[1] = mooSonneUsdce;

        bytes[] memory _bridges = new bytes[](1);
        _bridges[0] = abi.encodePacked(address(this));

        uint256[] memory _chainIds = new uint256[](1);
        _chainIds[0] = realOpChainId;

        uint16[] memory _stargateChainIds = new uint16[](1);
        _stargateChainIds[0] = opChainId;

        uint16[] memory _srcPoolIds = new uint16[](2);
        _srcPoolIds[0] = ethPoolId;
        _srcPoolIds[1] = usdcePoolId;

        uint16[] memory _dstPoolIds = new uint16[](2);
        _dstPoolIds[0] = ethPoolId;
        _dstPoolIds[1] = usdcePoolId;
        
        bridge = new BeefyStargateZap();
        bridge.initialize(stargate, native, thisChainId);
        bridge.addChains(_stargateChainIds, _chainIds, _bridges, gasLimits);
        bridge.addZappableVaults(opChainId, _tokens, _vaults);
        bridge.addInputTokens(opChainId, _tokens, _srcPoolIds, _dstPoolIds);
    }

    function test_bridge_out_usdce() public {
        vm.startPrank(user);
        deal(address(usdce), user, 10_000_000);

        IERC20(address(usdce)).approve(address(bridge), 10_000_000);
        uint256 gasAmount = bridge.bridgeCost(realOpChainId, usdce, mooSonneUsdce);
        bridge.beefIn{value: gasAmount}(realOpChainId, usdce, mooSonneUsdce, 10_000_000);

        uint256 bal = IERC20(address(usdce)).balanceOf(user);
        if (bal != 0) revert NoFundsMoved();

        vm.stopPrank();
    }

    function test_bad_bridge_out_usdce() public {
        vm.startPrank(user);
        deal(address(native), user, 10 ether);
        deal(address(usdce), user, 10_000_000);

        IERC20(address(usdce)).approve(address(bridge), 10_000_000);
        IERC20(address(native)).approve(address(bridge), 10 ether);
        uint256 gasAmount = bridge.bridgeCost(realOpChainId, usdce, mooSonneUsdce);

        vm.expectRevert(InvalidToken.selector);
        bridge.beefIn{value: gasAmount}(realOpChainId, usdce, mooSonneEth, 10_000_000);

        vm.expectRevert(InvalidVault.selector);
        bridge.beefIn{value: gasAmount}(realOpChainId, native, mooSiloEth, 10 ether);

        vm.expectRevert(InvalidChainId.selector);
        bridge.beefIn{value: gasAmount}(1, usdce, mooSonneUsdce, 10_000_000);

        vm.stopPrank();
    }

    function test_bridge_out_eth() public {
        vm.startPrank(user);
        vm.deal(user, 100 ether);

        uint256 gasAmount = bridge.bridgeCost(realOpChainId, usdce, mooSonneUsdce);

        uint256 amount = gasAmount + 10 ether;
        bridge.beefInEth{value: amount}(realOpChainId, mooSonneEth, 10 ether);

        vm.stopPrank();
    }

    function test_malicous_bridgeIn() public {
        vm.startPrank(address(user));

        vm.deal(address(bridge), 10 ether);
        BridgeData memory _bridgeData = BridgeData(user, native, mooSiloEth);
        bytes memory _payload = abi.encode(_bridgeData);

        vm.expectRevert(NotAuthorized.selector);
        bridge.sgReceive(
            opChainId,
            "",
            0,
            native,
            0,
            _payload
        );
        
        // console.log(andAfter);
        vm.stopPrank();
    }

    function test_bridge_in() public {
        vm.startPrank(address(stargate));

        vm.deal(address(bridge), 10 ether);
        BridgeData memory _bridgeData = BridgeData(user, native, mooSiloEth);
        bytes memory _payload = abi.encode(_bridgeData);

        uint256 before = IERC20(mooSiloEth).balanceOf(user);

        bridge.sgReceive(
            opChainId,
            "",
            0,
            native,
            0,
            _payload
        );
        
        uint256 andAfter = IERC20(mooSiloEth).balanceOf(user) - before;
        if (andAfter == 0) revert NoMooTokensOnArrival();
    
        // console.log(andAfter);

        vm.stopPrank();
    }

     function test_bridge_in_usdce() public {
        vm.startPrank(address(stargate));

        deal(address(usdce), address(bridge), 10_000_000);
        BridgeData memory _bridgeData = BridgeData(user, usdce, mooSiloUsdce);
        bytes memory _payload = abi.encode(_bridgeData);

        uint256 before = IERC20(mooSiloUsdce).balanceOf(user);

        bridge.sgReceive(
            opChainId,
            "",
            0,
            usdce,
            0,
            _payload
        );
        
        uint256 andAfter = IERC20(mooSiloUsdce).balanceOf(user) - before;
        if (andAfter == 0) revert NoMooTokensOnArrival();
    
        // console.log(andAfter);

        vm.stopPrank();
    }
}
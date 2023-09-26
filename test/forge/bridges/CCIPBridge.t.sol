pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {CCIPBridgeAdapter} from "../../../contracts/bridgeToken/adapters/ccip/CCIPBridgeAdapter.sol";
import {IRouterClient} from "../../../contracts/bridgeToken/adapters/ccip/interfaces/IRouterClient.sol";
import {BIFI} from "../../../contracts/bridgeToken/BIFI.sol";
import {XERC20} from "../../../contracts/bridgeToken/XERC20.sol";
import {XERC20Factory} from "../../../contracts/bridgeToken/XERC20Factory.sol";
import {XERC20Lockbox} from "../../../contracts/bridgeToken/XERC20Lockbox.sol";
import {IXERC20} from '../../../contracts/bridgeToken/interfaces/IXERC20.sol';
import {IXERC20Lockbox} from '../../../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol';

interface Ramp {
    function setAllowListEnabled(bool) external;
}

contract CCIPBridgeTest is Test {
    address constant zero = 0x0000000000000000000000000000000000000000;
    IRouterClient constant router = IRouterClient(0xE561d5E02207fb5eB32cca20a699E0d8919a1476);
    address constant user = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    Ramp constant ramp = Ramp(0xCC19bC4D43d17eB6859F0d22BA300967C97780b0);
    BIFI bifi;
    address xbifi;
    address lockbox;
    XERC20Factory factory;
    CCIPBridgeAdapter bridge;
    address[] contracts;

    bytes4 public constant EVM_EXTRA_ARGS_V1_TAG = 0x97a657c9;

    error WrongSender();
    error WrongSourceAddress();
    error InvalidChain();

    address[] zeros;
    uint256[] mintAmounts;
    uint256 mintAmount = 80000 ether;

    uint64 ccipOpId = 3734403246176062136;
    uint256 opId = 10;
    uint256[] chainIds;
    uint64[] ccipIds;

     function setUp() public {
        mintAmounts.push(mintAmount);
        zeros.push(zero);
        bifi = new BIFI();
        factory = new XERC20Factory();
        xbifi = factory.deployXERC20(
            "Beefy",
            "BIFI",
            mintAmounts,
            mintAmounts,
            zeros
        );

        lockbox = factory.deployLockbox(
            xbifi,
            address(bifi),
            false
        );

        contracts.push(address(router));
        bridge = new CCIPBridgeAdapter();
        bridge.initialize(IERC20(address(bifi)), IXERC20(xbifi), IXERC20Lockbox(lockbox), contracts);
        IXERC20(address(xbifi)).setLimits(address(bridge), mintAmount, mintAmount);

        chainIds.push(opId);
        ccipIds.push(ccipOpId);
        bridge.setChainIds(chainIds, ccipIds);

        IRouterClient.EVMExtraArgsV1 memory arg = IRouterClient.EVMExtraArgsV1(1500000, false);
        bytes memory extraArg = abi.encodeWithSelector(EVM_EXTRA_ARGS_V1_TAG, arg);
        bridge.setGasLimit(extraArg);
    }

    function test_bridge_out() public {

        // Allow our test bridge to send messages. 
        address owner = 0x44835bBBA9D40DEDa9b64858095EcFB2693c9449;
        vm.startPrank(owner);
        ramp.setAllowListEnabled(false);
        vm.stopPrank();

        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 10;
        uint64 ccipId = bridge.chainIdToCcipId(dstChainId);

        assertEq(ccipId, ccipOpId);

        uint256 gasNeeded = bridge.bridgeCost(dstChainId, 10 ether, user);

        bridge.bridge{value: gasNeeded}(dstChainId, 10 ether, user);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 10 ether);
        assertEq(userBal, 0);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }

    // Make sure we dont send messages to chains where the bridge doesnt exist. 
    function test_bridge_fail() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 42161;

        vm.expectRevert(InvalidChain.selector);
        bridge.bridge(dstChainId, 10 ether, user);

        vm.stopPrank();
    }

    function test_malicous_mint() public {
        // Test that only the router can call ccipReceive
        vm.startPrank(user);

        bytes memory data = abi.encode(user, 10 ether);

        IRouterClient.Any2EVMMessage memory message = IRouterClient.Any2EVMMessage(
            keccak256(abi.encode("MintTest")),
            ccipOpId,
            abi.encode(address(bridge)),
            data,
            new IRouterClient.EVMTokenAmount[](0)
        );

        vm.expectRevert(WrongSender.selector);
        bridge.ccipReceive(message);
       
        vm.stopPrank();

        // Test that message cannot be sent from invalid chain. 
        vm.startPrank(address(router));

        message = IRouterClient.Any2EVMMessage(
            keccak256(abi.encode("MintTest")),
            uint64(6433500567565415381), // Avalanche 
            abi.encode(address(bridge)),
            data,
            new IRouterClient.EVMTokenAmount[](0)
        );

        vm.expectRevert(InvalidChain.selector);
        bridge.ccipReceive(message);

        // Test that message cannot be sent from invalid sender.
        message = IRouterClient.Any2EVMMessage(
            keccak256(abi.encode("MintTest")),
            ccipOpId,
            abi.encode(user), // Incorrect source
            data,
            new IRouterClient.EVMTokenAmount[](0)
        );

        vm.expectRevert(WrongSourceAddress.selector);
        bridge.ccipReceive(message);
       
        vm.stopPrank();
    }


    function test_bridge_in() public {
        vm.startPrank(address(router));

        deal(address(bifi), lockbox, 10 ether);

        bytes memory data = abi.encode(user, 10 ether);

        IRouterClient.Any2EVMMessage memory message = IRouterClient.Any2EVMMessage(
            keccak256(abi.encode("MintTest")),
            ccipOpId,
            abi.encode(address(bridge)),
            data,
            new IRouterClient.EVMTokenAmount[](0)
        );

        bridge.ccipReceive(message);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 0);
        assertEq(userBal, 10 ether);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }
}
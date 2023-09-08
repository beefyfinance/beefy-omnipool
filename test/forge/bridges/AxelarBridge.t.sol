pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AxelarBridge} from "../../../contracts/bridgeToken/adapters/axelar/AxelarBridge.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {BIFI} from "../../../contracts/bridgeToken/BIFI.sol";
import {XERC20} from "../../../contracts/bridgeToken/XERC20.sol";
import {XERC20Factory} from "../../../contracts/bridgeToken/XERC20Factory.sol";
import {XERC20Lockbox} from "../../../contracts/bridgeToken/XERC20Lockbox.sol";
import {IXERC20} from '../../../contracts/bridgeToken/interfaces/IXERC20.sol';
import {IXERC20Lockbox} from '../../../contracts/bridgeToken/interfaces/IXERC20Lockbox.sol';
import {StringToAddress} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";

contract AxelarBridgeTest is Test {
    using StringToAddress for string;
    using AddressToString for address;

    address constant zero = 0x0000000000000000000000000000000000000000;
    IAxelarGateway constant gateway = IAxelarGateway(0x4F4495243837681061C4743b74B3eEdf548D56A5);
    IAxelarGasService constant gasService = IAxelarGasService(0x2d5d7d31F671F86C782533cc367F14109a082712);
    address constant user = 0x4fED5491693007f0CD49f4614FFC38Ab6A04B619;
    BIFI bifi;
    address xbifi;
    address lockbox;
    XERC20Factory factory;
    AxelarBridge bridge;

    bytes32 constant PREFIX_CONTRACT_CALL_APPROVED = keccak256('contract-call-approved');

    error InvalidChainId();
    error NotGateway();
    error NotApprovedByGateway();
    error WrongSourceAddress();

    address[] zeros;
    uint256[] mintAmounts;
    uint256 mintAmount = 80000 ether;

    string axelarOpId = "optimism";
    uint256 opId = 10;
    uint256[] chainIds;
    string[] axelarIds;

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

        bridge = new AxelarBridge();
        bridge.initialize(IERC20(address(bifi)), IXERC20(xbifi), IXERC20Lockbox(lockbox), 2000000, gateway, gasService);
        IXERC20(address(xbifi)).setLimits(address(bridge), mintAmount, mintAmount);

        chainIds.push(opId);
        axelarIds.push(axelarOpId);
        bridge.addChainIds(chainIds, axelarIds);
    }

    function test_bridge_out() public {
        vm.startPrank(user);
        deal(address(bifi), user, 10 ether);

        IERC20(address(bifi)).approve(address(bridge), type(uint).max);

        uint256 dstChainId = 10;

        bridge.bridge{value: .02 ether}(dstChainId, 10 ether, user);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 10 ether);
        assertEq(userBal, 0);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }

    function test_malicous_mint() public {
        vm.startPrank(user);

        bytes32 commandId = keccak256(abi.encode("kek"));
        string memory srcAddress = user.toString();
        bytes memory payload = abi.encode(user, 10 ether);

        // Caller is not the gateway
        vm.expectRevert(NotGateway.selector);
        bridge.execute(commandId, axelarOpId, srcAddress, payload);
        vm.stopPrank();

        vm.startPrank(address(gateway));

        // Chain id is not valid
        vm.expectRevert(InvalidChainId.selector);
        bridge.execute(commandId, "kek", srcAddress, payload);

        // Source address is not the wrong
        vm.expectRevert(WrongSourceAddress.selector);
        bridge.execute(commandId, axelarOpId, srcAddress, payload);

        // Message is not approved by the gateway
        vm.expectRevert(NotApprovedByGateway.selector);
        bridge.execute(commandId, axelarOpId, address(bridge).toString(), payload);

        vm.stopPrank();
    }

    function test_bridge_in() public {
        vm.startPrank(address(gateway));

        deal(address(bifi), lockbox, 10 ether);

        bytes32 commandId = keccak256(abi.encode("Success!"));
        string memory srcAddress = address(bridge).toString();
        bytes memory payload = abi.encode(user, 10 ether);

        // Source address is not the gateway

        // Build the verify key.
        bytes32 payloadHash = keccak256(payload);
        bytes32 key = keccak256(abi.encode(PREFIX_CONTRACT_CALL_APPROVED, commandId, axelarOpId, srcAddress, address(bridge), payloadHash));

        // The mapping slot on the gateway contract.
        bytes32 mappingSlot = 0x0000000000000000000000000000000000000000000000000000000000000004;

        // The slot where our key is stored from the mapping.
        bytes32 slot = keccak256(abi.encode(key, mappingSlot));

        // The value of to our key (true);
        bytes32 value = bytes32(abi.encode(true));

        // Store it. 
        vm.store(address(gateway), slot, value);

        bridge.execute(commandId, axelarOpId, srcAddress, payload);

        uint256 lockboxBal = IERC20(address(bifi)).balanceOf(address(lockbox));
        uint256 userBal = IERC20(address(bifi)).balanceOf(user);
        uint256 xbifiBal = IERC20(address(xbifi)).totalSupply();

        assertEq(lockboxBal, 0);
        assertEq(userBal, 10 ether);
        assertEq(xbifiBal, 0);

        vm.stopPrank();
    }
}
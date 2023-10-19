// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {BeefyBridgeAdapter} from "../BeefyBridgeAdapter.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {IXERC20} from  "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {StringToAddress} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";

// Axelar Token Bridge adapter for XERC20 tokens
contract AxelarBridge is BeefyBridgeAdapter {
    using SafeERC20 for IERC20;
    using StringToAddress for string;
    using AddressToString for address;
    
    IAxelarGateway public gateway;
    IAxelarGasService public gasService;

    // Chain id to axelar id mapping.
    mapping (uint256 => string) public chainIdToAxelarId;
    mapping (string => uint256) public axelarIdToChainId;

    // Errors
    error InvalidChainId();
    error NotApprovedByGateway();
    error WrongSourceAddress();

    /**@notice Initialize the bridge
     * @param _bifi BIFI token address
     * @param _xbifi xBIFI token address
     * @param _lockbox xBIFI lockbox address
     */
    function initialize(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        address[] calldata _contracts
    ) public override initializer {
        __Ownable_init();
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;
        gateway = IAxelarGateway(_contracts[0]);
        gasService = IAxelarGasService(_contracts[1]);

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
            IERC20(address(xBIFI)).safeApprove(address(lockbox), type(uint).max);
        }
    }

    function _bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to) internal override {
        if (abi.encode(chainIdToAxelarId[_dstChainId]).length == 0) revert InvalidChainId();

        _bridgeOut(_user, _amount);

        // Send message to receiving bridge to mint tokens to user. 
        bytes memory payload = abi.encode(_to, _amount);
 
        // Pay for our transaction on the other chain.
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            chainIdToAxelarId[_dstChainId],
            address(this).toString(),
            payload,
            _user
        );

        // Send message to receiving bridge to mint tokens to user.
        gateway.callContract(
            chainIdToAxelarId[_dstChainId],
            address(this).toString(),
            payload
        );

        emit BridgedOut(_dstChainId, _user, _to, _amount);
    }

    // Add a new chain id to the mapping. 
    function addChainIds(uint256[] calldata _chainIds, string[] calldata _axelarIds) external onlyOwner {
        for (uint i; i < _chainIds.length; ++i) {
            chainIdToAxelarId[_chainIds[i]] = _axelarIds[i];
            axelarIdToChainId[_axelarIds[i]] = _chainIds[i];
        }
    }

    // Execute a bridge in. Callable only by the gateway.
    function execute(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) external {
        if (axelarIdToChainId[sourceChain] == 0) revert InvalidChainId();
        if (sourceAddress.toAddress() != address(this)) revert WrongSourceAddress();
        
        bytes32 payloadHash = keccak256(payload);
        if (!gateway.validateContractCall(commandId, sourceChain, sourceAddress, payloadHash)) revert NotApprovedByGateway();
       
        (address user, uint256 amount) = abi.decode(payload, (address,uint256));

        _bridgeIn(axelarIdToChainId[sourceChain], user, amount);    
    }
}
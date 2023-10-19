// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {BeefyBridgeAdapter} from "../BeefyBridgeAdapter.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin-4/contracts/proxy/utils/Initializable.sol";

import {IOptimismBridge} from "./IOptimismBridge.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";

// Optimism Token Bridge adapter for XERC20 tokens
contract OptimismBridgeAdapter is BeefyBridgeAdapter {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IOptimismBridge public opBridge;
    uint256 public dstChainId;
    uint32 public gasLimit;

    // Errors
    error WrongSender();

    // Only allow bridge to call
    modifier onlyBridge {
        _onlyBridge();
        _;
    }

    function _onlyBridge() private view {
        if (address(opBridge) != msg.sender) revert WrongSender();
        if (opBridge.xDomainMessageSender() != address(this)) revert WrongSender();
    }

    /**@notice Initialize the bridge
     * @param _bifi BIFI token address
     * @param _xbifi xBIFI token address
     * @param _lockbox xBIFI lockbox address
     * @param _contracts Additional contracts needed
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
        opBridge = IOptimismBridge(_contracts[0]);
        dstChainId = 10;
        gasLimit = 1900000;

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
            IERC20(address(xBIFI)).safeApprove(address(lockbox), type(uint).max);
        }
    }

    function _bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to) internal override {
        _bridgeOut(_user, _amount);

        bytes memory message = abi.encodeWithSignature(
            "mint(address,uint256)",
            _to,
            _amount
        );

        // Send a message to our bridge counterpart which will be this contract at the same address on L2/L1. 
       opBridge.sendMessage(address(this), message, gasLimit);

        emit BridgedOut(_dstChainId, _user, _to, _amount);
    }

    /**@notice Bridge In Funds, callable by Op Bridge
     * @param _user Address to receive funds
     * @param _amount Amount of BIFI to bridge in
     */
    function mint(
        address _user,
        uint256 _amount
    ) external onlyBridge {

        _bridgeIn(dstChainId, _user, _amount);    
    }
}
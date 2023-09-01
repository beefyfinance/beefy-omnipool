// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin-4/contracts/proxy/utils/Initializable.sol";
import {IOptimismBridge} from "./IOptimismBridge.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";

contract OptimismBridgeAdapter is Initializable {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IERC20 public BIFI;
    IXERC20 public xBIFI;
    IXERC20Lockbox public lockbox;
    IOptimismBridge public opBridge;
    uint32 public gasLimit;

    event BridgedOut(uint256 indexed dstChainId, address indexed bridgeUser, address indexed tokenReceiver, uint256 amount);
    event BridgedIn(uint256 indexed srcChainId, address indexed tokenReceiver, uint256 amount);

    error WrongSender();

    modifier onlyBridge {
        _onlyBridge();
        _;
    }

    function _onlyBridge() private view {
        if (address(opBridge) != msg.sender) revert WrongSender();
        if (opBridge.xDomainMessageSender() != address(this)) revert WrongSender();
    }

    function initialize(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        IOptimismBridge _bridge
    ) public initializer {
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;
        opBridge = _bridge;
        gasLimit = 1900000;

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
        }
    }

    function bridge(uint256 _dstChainId, uint256 _amount, address _to) external payable {
        
        // Lock BIFI in lockbox and burn minted tokens. 
        if (address(lockbox) != address(0)) {
            BIFI.safeTransferFrom(msg.sender, address(this), _amount);
            lockbox.deposit(_amount);
            xBIFI.burn(address(this), _amount);
        } else xBIFI.burn(msg.sender, _amount);

        bytes memory message = abi.encodeWithSignature(
            "mint(address,uint256)",
            _to,
            _amount
        );

        // Send a message to our bridge counterpart which will be this contract at the same address on L2/L1. 
       opBridge.sendMessage(address(this), message, gasLimit);

        emit BridgedOut(_dstChainId, msg.sender, _to, _amount);
    }

    // Keep adapter interface. 
    function bridgeCost(uint16, uint256, address) external pure returns (uint256 gasCost) {
       return 0; // unused;
    }

    function mint(
        address _user,
        uint256 _amount
    ) external onlyBridge {

        xBIFI.mint(address(this), _amount);
        if (address(lockbox) != address(0)) {
            lockbox.withdraw(_amount);
            BIFI.transfer(_user, _amount);
        } else IERC20(address(xBIFI)).transfer(_user, _amount); 

        emit BridgedIn(10, _user, _amount);      
    }
}
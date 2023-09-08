// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin-4/contracts/proxy/utils/Initializable.sol";
import {IOptimismBridge} from "./IOptimismBridge.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";

// Optimism Token Bridge adapter for XERC20 tokens
contract OptimismBridgeAdapter is Initializable {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IERC20 public BIFI;
    IXERC20 public xBIFI;
    IXERC20Lockbox public lockbox;
    IOptimismBridge public opBridge;
    uint32 public gasLimit;

    // Events
    event BridgedOut(uint256 indexed dstChainId, address indexed bridgeUser, address indexed tokenReceiver, uint256 amount);
    event BridgedIn(uint256 indexed srcChainId, address indexed tokenReceiver, uint256 amount);

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
     * @param _bridge Optimism bridge address
     */
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

    /**@notice  Bridge out funds with permit
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     * @param _deadline Deadline for permit
     * @param v v value for permit
     * @param r r value for permit
     * @param s s value for permit
     */
    function bridge(uint256 _dstChainId, uint256 _amount, address _to, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external payable {
        IERC20Permit(address(BIFI)).permit(msg.sender, address(this), _amount, _deadline, v, r, s);
        bridge(_dstChainId, _amount, _to);
    }

    /**@notice Bridge Out Funds
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridge(uint256 _dstChainId, uint256 _amount, address _to) public payable {
        
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

    // Keep adapter interface. We only pay the tx gas for this bridge. 
    function bridgeCost(uint256, uint256, address) external pure returns (uint256 gasCost) {
       return 0; // unused;
    }

    /**@notice Bridge In Funds, callable by Op Bridge
     * @param _user Address to receive funds
     * @param _amount Amount of BIFI to bridge in
     */
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
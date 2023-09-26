// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IXERC20} from "../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../interfaces/IXERC20Lockbox.sol";

// Beefy Bridge Adapter Base
contract BeefyBridgeAdapter is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IERC20 public BIFI;
    IXERC20 public xBIFI;
    IXERC20Lockbox public lockbox;

    // Events
    event BridgedOut(uint256 indexed dstChainId, address indexed bridgeUser, address indexed tokenReceiver, uint256 amount);
    event BridgedIn(uint256 indexed srcChainId, address indexed tokenReceiver, uint256 amount);

    /**@notice Initialize the bridge
     * @param _bifi BIFI token address
     * @param _xbifi xBIFI token address
     * @param _lockbox xBIFI lockbox address
     */
    function initialize(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        address[] calldata 
    ) public virtual initializer {
        __Ownable_init();
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
        }
    }

     /**@notice  Bridge out funds with permit
     * @param _user User address
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     * @param _deadline Deadline for permit
     * @param v v value for permit
     * @param r r value for permit
     * @param s s value for permit
     */
    function bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external virtual payable {
        IERC20Permit(address(BIFI)).permit(_user, address(this), _amount, _deadline, v, r, s);
        _bridge(_user, _dstChainId, _amount, _to);
    }

    /**@notice Bridge Out Funds
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridge(uint256 _dstChainId, uint256 _amount, address _to) external virtual payable {
        _bridge(msg.sender, _dstChainId, _amount, _to);
    }

    function _bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to) internal virtual {
        
        _bridgeOut(_user, _amount);

        emit BridgedOut(_dstChainId, _user, _to, _amount);
    }

    function _bridgeOut(address _user, uint256 _amount) internal virtual {
        // Lock BIFI in lockbox and burn minted tokens. 
        if (address(lockbox) != address(0)) {
            BIFI.safeTransferFrom(_user, address(this), _amount);
            lockbox.deposit(_amount);
            xBIFI.burn(address(this), _amount);
        } else xBIFI.burn(_user, _amount);
    }

    function _bridgeIn(address _user, uint256 _amount) internal virtual {
        xBIFI.mint(address(this), _amount);
        if (address(lockbox) != address(0)) {
            lockbox.withdraw(_amount);
            BIFI.transfer(_user, _amount);
        } else IERC20(address(xBIFI)).transfer(_user, _amount); 
    }

    /**@notice Estimate bridge cost
     * @param _dstChainId Destination chain id
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridgeCost(uint256 _dstChainId, uint256 _amount, address _to) external virtual view returns (uint256 gasCost) {
        _dstChainId; _amount; _to;
        return 0;
    }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWrappedNative} from "../../interfaces/IWrappedNative.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStargate} from "../../interfaces/bridge/IStargate.sol";
import {IBeefyVault} from "../interfaces/IBeefyVault.sol";

// Beefy's Stargate Zap Receiver for Single Asset X-Chain Zapping
contract BeefyStargateZapReceiver is OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // Initializable variables
    address public stargate;
    address public wnative;

    struct BridgeData {
        address vault;
        address token;
        address receiver;
    }

    // Errors
    error NotAuthorized();
    error FailedToSendNative();

    // Events
    event DepositSuccess(address indexed vault, address indexed user, uint256 shares);
    event DepositFailed(address indexed vault, address indexed user);

    function initialize(
        address _stargate,
        address _wnative
    ) public initializer {
        __Ownable_init();

        stargate = _stargate;
        wnative = _wnative;
    }

    // Stargate receive function
    function sgReceive(
        uint16 /* _chainId */,
        bytes memory /* _srcAddress */,
        uint256 /* _nonce */,
        address /* _token */,
        uint256 /* _amountLD */,
        bytes memory payload
    ) external payable {
        if (msg.sender != stargate) revert NotAuthorized();

        BridgeData memory _data = abi.decode(payload, (BridgeData));
        try this._depositLocal(_data) {
            // was successful
        }
        catch {
            _depositFailed(_data);
        }
    }

    function _depositLocal(BridgeData memory _data) public {
        if (msg.sender != address(this)) revert NotAuthorized();

        // Wrap if needed
        uint256 rawNative = address(this).balance;
        if (rawNative > 0) {
            IWrappedNative(wnative).deposit{value: rawNative}();
        }

        // Deposit
        uint256 bal = IERC20(_data.token).balanceOf(address(this));
        _approveTokenIfNeeded(_data.token, _data.vault, bal);
        IBeefyVault(_data.vault).deposit(bal);

        // Send shares
        uint256 shares = IERC20(_data.vault).balanceOf(address(this));
        IERC20(_data.vault).safeTransfer(_data.receiver, shares);

        emit DepositSuccess(_data.vault, _data.receiver, shares);
    }

    function _depositFailed(BridgeData memory _data) private {
        _sendAllNative(_data.receiver);

        if (_data.token != address(0)) {
            IERC20 token = IERC20(_data.token);
            uint256 bal = token.balanceOf(address(this));
            if (bal > 0) {
                token.safeTransfer(_data.receiver, bal);
            }
        }

        emit DepositFailed(_data.vault, _data.receiver);
    }

    function _sendAllNative(address _receiver) private {
        uint256 rawNative = address(this).balance;
        if (rawNative > 0) {
            (bool sent,) = _receiver.call{value: rawNative}("");
            if (!sent) {
                revert FailedToSendNative();
            }
        }
    }

    function _approveTokenIfNeeded(address _token, address _spender, uint256 _amount) private {
        if (IERC20(_token).allowance(address(this), _spender) < _amount) {
            IERC20(_token).approve(_spender, type(uint256).max);
        }
    }

    function inCaseTokensGetStuck(address _token) external onlyOwner {
        if (_token == address(0)) {
            _sendAllNative(msg.sender);
        } else {
            uint256 amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(msg.sender, amount);
        }
    }

    receive() external payable {}
}
 
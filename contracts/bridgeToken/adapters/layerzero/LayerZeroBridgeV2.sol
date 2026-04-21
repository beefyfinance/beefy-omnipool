// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; 

import {BeefyBridgeAdapter} from "../BeefyBridgeAdapter.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from  "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";
import {OAppUpgradeable, Origin, MessagingFee} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";

// Lazyer Zero Token Bridge adapter for XERC20 tokens
contract LayerZeroBridge is OAppUpgradeable, BeefyBridgeAdapter {
    using SafeERC20 for IERC20;

    // LZ V2 encoded options for lzReceive execution gas
    bytes public lzOptions;

    // Chain id mappings (using uint32 for LZ V2 endpoint IDs)
    mapping (uint256 => uint32) public chainIdToEid;
    mapping (uint32 => uint256) public eidToChainId;

    /**@notice Constructor
     * @param _endpoint LayerZero endpoint address
     */
    constructor(address _endpoint) OAppUpgradeable(_endpoint) {}

    /**@notice Initialize the bridge
     * @param _bifi BIFI token address
     * @param _xbifi xBIFI token address
     * @param _lockbox xBIFI lockbox address
     * @param _delegate Delegate for LZ endpoint configuration
     */
    function initialize(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        address _delegate
    ) public initializer {
        __Ownable_init();
        __OApp_init(_delegate);
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
            IERC20(address(xBIFI)).safeApprove(address(lockbox), type(uint).max);
        }
    }

    /**@notice Bridge BIFI to destination chain
     * @param _user User address
     * @param _dstChainId Destination chain id
     * @param _amount Amount of BIFI to bridge
     * @param _to Address to receive funds on destination chain
     */
    function _bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to) internal override {
        require(lzOptions.length > 0, "LayerZeroBridge: lzOptions not set");
        _bridgeOut(_user, _amount);

        // Send message to receiving bridge to mint tokens to user.
        bytes memory payload = abi.encode(_to, _amount);
        _lzSend(
            chainIdToEid[_dstChainId],
            payload,
            lzOptions,
            MessagingFee(msg.value, 0),
            payable(_user)
        );

        emit BridgedOut(_dstChainId, _user, _to, _amount);
    }

    /**@notice Estimate gas cost to bridge out funds
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridgeCost(uint256 _dstChainId, uint256 _amount, address _to) external override view returns (uint256 gasCost) {
        bytes memory payload = abi.encode(_to, _amount);
        gasCost = _quote(chainIdToEid[_dstChainId], payload, lzOptions, false).nativeFee;
    }

    /**@notice Add chain ids to the bridge
     * @param _chainIds Chain ids to add
     * @param _eids Endpoint ids to add
     */
    function addChainIds(uint256[] calldata _chainIds, uint32[] calldata _eids) external onlyOwner {
        for (uint i; i < _chainIds.length; ++i) {
            chainIdToEid[_chainIds[i]] = _eids[i];
            eidToChainId[_eids[i]] = _chainIds[i];
        }
    }


    /**@notice Receive message from LayerZero
     * @param _origin Source chain info
     * @param _payload Message payload
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata _payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (address user, uint256 amount) = abi.decode(_payload, (address, uint256));
        _bridgeIn(eidToChainId[_origin.srcEid], user, amount);
    }

    /**@notice Set LZ V2 encoded options for lzReceive execution
     * @param _options Encoded options bytes
     */
    function setOptions(bytes calldata _options) external onlyOwner {
        lzOptions = _options;
    }
}
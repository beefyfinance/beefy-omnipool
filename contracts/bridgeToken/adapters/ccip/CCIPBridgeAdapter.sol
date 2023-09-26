// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {BeefyBridgeAdapter} from "../BeefyBridgeAdapter.sol";
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {IERC20Permit} from "@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin-4/contracts/utils/introspection/IERC165.sol";
import {IRouterClient} from "./interfaces/IRouterClient.sol";
import {IAny2EVMMessageReceiver} from "./interfaces/IAny2EVMMessageReceiver.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";

// Chainlink CCIP Token Bridge adapter for XERC20 tokens
contract CCIPBridgeAdapter is BeefyBridgeAdapter {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IRouterClient public router;

    // Bridge params
    bytes public extraArgs;

    // Chain id mappings
    mapping (uint64 => bool) public whitelistedChains;
    mapping (uint256 => uint64) public chainIdToCcipId;
    mapping (uint64 => uint256) public ccipIdToChainId;

    // Errors
    error WrongSender();
    error WrongSourceAddress();
    error InvalidChain();

    // Only allow bridge to call
    modifier onlyBridge {
        _onlyBridge();
        _;
    }

    function _onlyBridge() private view {
        if (address(router) != msg.sender) revert WrongSender();
    }

     /**@notice Initialize the bridge
     * @param _bifi BIFI token address
     * @param _xbifi xBIFI token address
     * @param _lockbox xBIFI lockbox address
     * @param _contracts additional contracts needed
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
        router = IRouterClient(_contracts[0]);

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
        }
        
    }

    function _bridge(address _user, uint256 _dstChainId, uint256 _amount, address _to) internal override {
        if (!whitelistedChains[chainIdToCcipId[_dstChainId]]) revert InvalidChain();
        
       _bridgeOut(_user, _amount);

        // Create a bridge message struct with the data we want to send.
        IRouterClient.EVM2AnyMessage memory message = IRouterClient.EVM2AnyMessage(
            abi.encode(address(this)),
            abi.encode(_to, _amount),
            new IRouterClient.EVMTokenAmount[](0),
            address(0),
            extraArgs
        );

        // Send a message to our bridge counterpart which will be this contract at the same address on dest chain. 
        router.ccipSend{value: msg.value}(chainIdToCcipId[_dstChainId], message);

        emit BridgedOut(_dstChainId, _user, _to, _amount);
    }

    /**@notice Estimate bridge cost
     * @param _dstChainId Destination chain id
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridgeCost(uint256 _dstChainId, uint256 _amount, address _to) external override view returns (uint256 gasCost) {
        IRouterClient.EVM2AnyMessage memory message = IRouterClient.EVM2AnyMessage(
            abi.encode(address(this)),
            abi.encode(_to, _amount),
            new IRouterClient.EVMTokenAmount[](0),
            address(0),
            extraArgs
        );

        return router.getFee(chainIdToCcipId[_dstChainId], message);
    }

    /**@notice Set chain ids
     * @param _chainIds Array of chain ids
     * @param _ccipChainIds Array of CCIP chain ids
     */
    function setChainIds(uint256[] calldata _chainIds, uint64[] calldata _ccipChainIds) external onlyOwner {
        for (uint i; i < _chainIds.length; ++i) {
            chainIdToCcipId[_chainIds[i]] = _ccipChainIds[i];
            ccipIdToChainId[_ccipChainIds[i]] = _chainIds[i];
            whitelistedChains[_ccipChainIds[i]] = true;
        }
    }

    /**@notice Executable by Chainlink router, Bridge funds in and mint/give BIFI to the user
     * @param message Bridge message
     */
    function ccipReceive(
       IRouterClient.Any2EVMMessage memory message
    ) external onlyBridge {
        if (!whitelistedChains[message.sourceChainSelector]) revert InvalidChain();
        if (abi.decode(message.sender, (address)) != address(this)) revert WrongSourceAddress();
        (address _user, uint256 _amount) = abi.decode(message.data, (address,uint256));

        _bridgeIn(_user, _amount);

        emit BridgedIn(ccipIdToChainId[message.sourceChainSelector], _user, _amount);      
    }

    /**@notice Set extra args (gasLimit) for bridge messages
     * @param _extraArgs Extra args for bridge messages
     */
    function setGasLimit(bytes calldata _extraArgs) external onlyOwner {
        extraArgs = _extraArgs;
    }

    /// @notice IERC165 supports an interfaceId
    /// @param interfaceId The interfaceId to check
    /// @return true if the interfaceId is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
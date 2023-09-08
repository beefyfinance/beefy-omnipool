// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRouterClient} from "./interfaces/IRouterClient.sol";
import {IXERC20} from "../../interfaces/IXERC20.sol";
import {IXERC20Lockbox} from "../../interfaces/IXERC20Lockbox.sol";

// Chainlink CCIP Token Bridge adapter for XERC20 tokens
contract CCIPBridgeAdapter is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IERC20 public BIFI;
    IXERC20 public xBIFI;
    IXERC20Lockbox public lockbox;
    IRouterClient public router;

    // Bridge params
    bytes public extraArgs;

    // Chain id mappings
    mapping (uint64 => bool) public whitelistedChains;
    mapping (uint256 => uint64) public chainIdToCcipId;
    mapping (uint64 => uint256) public ccipIdToChainId;

    // Events
    event BridgedOut(uint256 indexed dstChainId, address indexed bridgeUser, address indexed tokenReceiver, uint256 amount);
    event BridgedIn(uint256 indexed srcChainId, address indexed tokenReceiver, uint256 amount);

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
     * @param _router Chainlink CCIP router address
     */
    function initialize(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        IRouterClient _router
    ) public initializer {
        __Ownable_init();
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;
        router = _router;

        if (address(lockbox) != address(0)) {
            BIFI.safeApprove(address(lockbox), type(uint).max);
        }
    }

    /**@notice Bridge Out Funds
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridge(uint256 _dstChainId, uint256 _amount, address _to) external payable {
        if (!whitelistedChains[chainIdToCcipId[_dstChainId]]) revert InvalidChain();
        
        // Lock BIFI in lockbox and burn minted tokens. 
        if (address(lockbox) != address(0)) {
            BIFI.safeTransferFrom(msg.sender, address(this), _amount);
            lockbox.deposit(_amount);
            xBIFI.burn(address(this), _amount);
        } else xBIFI.burn(msg.sender, _amount);

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

        emit BridgedOut(_dstChainId, msg.sender, _to, _amount);
    }

    /**@notice Estimate bridge cost
     * @param _dstChainId Destination chain id
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridgeCost(uint256 _dstChainId, uint256 _amount, address _to) external view returns (uint256 gasCost) {
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

        xBIFI.mint(address(this), _amount);
        if (address(lockbox) != address(0)) {
            lockbox.withdraw(_amount);
            BIFI.transfer(_user, _amount);
        } else IERC20(address(xBIFI)).transfer(_user, _amount); 

        emit BridgedIn(ccipIdToChainId[message.sourceChainSelector], _user, _amount);      
    }

    /**@notice Set extra args (gasLimit) for bridge messages
     * @param _extraArgs Extra args for bridge messages
     */
    function setGasLimit(bytes calldata _extraArgs) external onlyOwner {
        extraArgs = _extraArgs;
    }
}
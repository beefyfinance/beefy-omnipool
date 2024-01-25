// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWrappedNative} from "../../interfaces/IWrappedNative.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStargate} from "../../interfaces/bridge/IStargate.sol";
import {IBeefyVault} from "../interfaces/IBeefyVault.sol";

// Beefy's Stargate Zap Bridge for Singles Asset Same Token Zapping 
contract BeefyStargateZap is OwnableUpgradeable {

    // Address needed 
    address public stargate;
    address public native;
    uint16 public thisChainId;

    // Our structs 
    struct ChainData {
        bytes bridge;
        uint256 gasLimit;
    }

    struct BridgeData {
        address user;
        address vault;
    }

    struct PoolIds {
        uint16 srcPoolId;
        uint16 dstPoolId;
    }

    // Needed mappings
    mapping (uint256 => uint16) private chainIds;
    mapping (uint16 => uint256) public reverseChainIds;
    mapping (uint16 => ChainData) public chainData;
    mapping (uint16 => mapping (address => PoolIds)) public chainToInputToPoolIds;
    mapping (uint16 => mapping (address => address)) public vaultToInput;

    // Errors
    error InvalidVault();
    error InvalidToken();
    error InvalidChainId();
    error NotAuthorized();
    error FailedToSendEther();

    // Events
    event BeefIn(uint256 indexed dstChainId, address indexed token, address vault, uint256 amount);
    event TokenAdded(uint256 indexed dstChainId, address indexed token);
    event ChainAdded(uint16 indexed stargateId, uint256 indexed dstChainId, bytes bridge, uint256 gasLimit);
    event VaultAdded(uint256 indexed dstChainId, address indexed vault, address indexed token);
    event BridgedIn(uint256 indexed srcChainId, address indexed vault, address indexed user, uint256 amount);
    event Error();

    function initialize(
        address _stargate,
        address _native,
        uint16 _thisChainId
    ) public initializer {
        __Ownable_init();

        stargate = _stargate;
        native = _native;
        thisChainId = _thisChainId;
    }

    /**
        * @notice Beef in to another chain with ETH 
        * @param _dstChainId The chain id of the destination chain
        * @param _vault The vault to beef in to
        * @param _amount The amount of tokens to beef in
     */
    function beefInEth(uint256 _dstChainId, address _vault, uint256 _amount) external payable {
        _beefIn(_dstChainId, native, _vault, _amount);
    }

    /**
        * @notice Beef in to another chain with ERC20 tokens
        * @param _dstChainId The chain id of the destination chain
        * @param _token The token to beef in
        * @param _vault The vault to beef in to
        * @param _amount The amount of tokens to beef in
     */
    function beefIn(uint256 _dstChainId, address _token, address _vault, uint256 _amount) external payable{
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        if (_token == native) IWrappedNative(native).withdraw(_amount);

        _beefIn(_dstChainId, _token, _vault, _amount);
    }

    function _beefIn(uint256 _dstChainId,  address _token, address _vault, uint256 _amount) private {
        uint16 stargateDstChainId = chainIds[_dstChainId];
        if (stargateDstChainId == 0) revert InvalidChainId();
        if (vaultToInput[stargateDstChainId][_vault] == address(0)) revert InvalidVault();
        if (vaultToInput[stargateDstChainId][_vault] != _token) revert InvalidToken();

        ChainData memory _chainData = chainData[stargateDstChainId];
        IStargate.lzTxObj memory _lzTxObj = IStargate.lzTxObj({
            dstGasForCall: _chainData.gasLimit,
            dstNativeAmount: 0,
            dstNativeAddr: "0x"
        });

        BridgeData memory _bridgeData = BridgeData({
            user: msg.sender,
            vault: _vault
        });

        bytes memory _payload = abi.encode(_bridgeData);

        uint256 gasAmount = address(this).balance;

        PoolIds memory _poolIds = chainToInputToPoolIds[stargateDstChainId][_token];
        
        _approveTokenIfNeeded(_token, stargate);

        IStargate(stargate).swap{ value: gasAmount }(
            stargateDstChainId,
            _poolIds.srcPoolId,
            _poolIds.dstPoolId,
            payable(msg.sender),
            _amount,
            0,
            _lzTxObj,
            _chainData.bridge,
            _payload
        );

        uint256 rawNative = address(this).balance;
        if (rawNative > 0) {
            (bool sent,) = msg.sender.call{value: rawNative}("");
            if(!sent) revert FailedToSendEther();
        }
            
        emit BeefIn(_dstChainId, _token, _vault, _amount);
    }

    // Stargate receive function 
    function sgReceive(
        uint16 _chainId,
        bytes memory /* _srcAddress */,
        uint256 /* _nonce */,
        address /*token*/,
        uint256 /*amountLD*/,
        bytes memory payload
    ) external payable {
        if (msg.sender != stargate) revert NotAuthorized();
        BridgeData memory _bridgeData = abi.decode(payload, (BridgeData));
        address token = IBeefyVault(_bridgeData.vault).want();
        try this._beefInLocal(_chainId, _bridgeData, token) {
            // Do Nothing
        } catch {
            uint256 rawNative = address(this).balance;
            if (rawNative > 0) {
                (bool sent,) = _bridgeData.user.call{value: rawNative}("");
                if(!sent) revert FailedToSendEther();
            } 

            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal > 0) IERC20(token).transfer(_bridgeData.user, bal);
            emit Error();
        }
    }

    function _beefInLocal(uint16 _chainId, BridgeData memory _bridgeData, address _token) public {
        if (msg.sender != address(this)) revert NotAuthorized();

        uint256 rawNative = address(this).balance;
        if (rawNative > 0) IWrappedNative(native).deposit{value: rawNative}();

        _approveTokenIfNeeded(_token, _bridgeData.vault);
        uint256 bal = IERC20(_token).balanceOf(address(this));
        IBeefyVault(_bridgeData.vault).deposit(bal);

        uint256 mooBal = IERC20(_bridgeData.vault).balanceOf(address(this));
        IERC20(_bridgeData.vault).transfer(_bridgeData.user, mooBal);

        emit BridgedIn(reverseChainIds[_chainId], _bridgeData.vault, _bridgeData.user, mooBal);
    }

    function bridgeCost(uint256 _dstChainId, address _token, address _vault) external view returns (uint256 gasCost) {
        uint16 stargateDstChainId = chainIds[_dstChainId];
        if (vaultToInput[stargateDstChainId][_vault] == address(0)) revert InvalidVault();
        if (vaultToInput[stargateDstChainId][_vault] != _token) revert InvalidToken();
        if (stargateDstChainId == 0) revert InvalidChainId();

        ChainData memory _chainData = chainData[stargateDstChainId];
        IStargate.lzTxObj memory _lzTxObj = IStargate.lzTxObj({
            dstGasForCall: _chainData.gasLimit,
            dstNativeAmount: 0,
            dstNativeAddr: "0x"
        });

        BridgeData memory _bridgeData = BridgeData({
            user: msg.sender,
            vault: _vault
        });

        bytes memory _payload = abi.encode(_bridgeData);

        return _stargateGasCost(stargateDstChainId, _payload, _chainData.bridge, _lzTxObj);
    }

    function _stargateGasCost(uint16 _dstChainId, bytes memory _payload, bytes memory _dstAddress, IStargate.lzTxObj memory _lzTxObj) private view returns (uint256 gasAmount) {
         (gasAmount,) = IStargate(stargate).quoteLayerZeroFee(
            _dstChainId,
            1, // TYPE_SWAP_REMOTE
            _dstAddress,
            _payload,
            _lzTxObj
        );
    }

    /**
        * @notice Add chains to the stargate zap
        * @param _stargateChainIds The chain ids of the stargate
        * @param _chainIds The chain ids of the destination chains
        * @param _bridges The bridges of the destination chains
        * @param _gasLimits The gas limits of the destination chains
     */
    function addChains (uint16[] calldata _stargateChainIds, uint256[] calldata _chainIds, bytes[] calldata _bridges, uint256[] calldata _gasLimits) external onlyOwner {
        _addChains(_stargateChainIds, _chainIds, _bridges, _gasLimits);
    }

    function _addChains (uint16[] calldata _stargateChainIds, uint256[] calldata _chainIds, bytes[] calldata _bridges, uint256[] calldata _gasLimits) private {
        for (uint i; i < _chainIds.length; ++i) {
            chainIds[_chainIds[i]] = _stargateChainIds[i];
            reverseChainIds[_stargateChainIds[i]] = _chainIds[i];
            chainData[_stargateChainIds[i]] = ChainData({
                bridge: _bridges[i],
                gasLimit: _gasLimits[i]
            });

            emit ChainAdded(_stargateChainIds[i], _chainIds[i], _bridges[i], _gasLimits[i]);
        }
    }

    /**
        * @notice Add tokens to the stargate zap
        * @param _chainId The chain ids of the destination chains
        * @param _tokens The tokens to add
        * @param _srcPoolIds The source pool ids of the tokens
        * @param _dstPoolIds The destination pool ids of the tokens
     */
    function addInputTokens(uint16 _chainId, address[] calldata _tokens, uint16[] calldata _srcPoolIds, uint16[] calldata _dstPoolIds) external onlyOwner {
        _addInputTokens(_chainId, _tokens, _srcPoolIds, _dstPoolIds);
    }

    function _addInputTokens(uint16 _chainId, address[] calldata _tokens, uint16[] calldata _srcPoolIds, uint16[] calldata _dstPoolIds) private {
        for (uint i; i < _tokens.length; ++i) {
            chainToInputToPoolIds[_chainId][_tokens[i]] = PoolIds({
                srcPoolId: _srcPoolIds[i],
                dstPoolId: _dstPoolIds[i]
            });

            emit TokenAdded(_chainId, _tokens[i]);
        }
    }
    
    /**
        * @notice Add vaults to the stargate zap
        * @param _chainId The chain ids of the destination chains
        * @param _tokens The tokens to add
        * @param _vaults The vaults to add
     */
    function addZappableVaults(uint16 _chainId, address[] calldata _tokens, address[] calldata _vaults) external onlyOwner {
        _addZappableVaults(_chainId, _tokens, _vaults);
    }

    function _addZappableVaults(uint16 _chainId, address[] calldata _tokens, address[] calldata _vaults) private {
        for (uint i; i < _tokens.length; ++i) {
            vaultToInput[_chainId][_vaults[i]] = _tokens[i];

            emit VaultAdded(_chainId, _vaults[i], _tokens[i]);
        }
    }

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).approve(spender, type(uint256).max);
        }
    }

    function inCaseTokensGetStuck(address _token, bool _native) external onlyOwner {
        if (_native) {
            uint256 _nativeAmount = address(this).balance;
            (bool sent,) = msg.sender.call{value: _nativeAmount}("");
            if(!sent) revert FailedToSendEther();
        } else {
            uint256 _amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).transfer(msg.sender, _amount);
        }
    }

    receive() external payable {}
}
 
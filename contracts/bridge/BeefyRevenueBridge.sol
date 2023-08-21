// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Essential interfaces
import {IERC20} from "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Address} from "@openzeppelin-4/contracts/utils/Address.sol";

// Bridge Interfaces
import {IAxelar} from "../interfaces/bridge/IAxelar.sol";
import {ICircle} from "../interfaces/bridge/ICircle.sol";
import {IStargate} from "../interfaces/bridge/IStargate.sol";
import {ISynapse} from "../interfaces/bridge/ISynapse.sol";
import {IzkEVM} from "../interfaces/bridge/IzkEVM.sol";
import {IzkSync} from "../interfaces/bridge/IzkSync.sol";

//Swap interfaces and utils
import {IUniswapRouterETH} from "../interfaces/swap/IUniswapRouterETH.sol";
import {ISolidlyRouter} from "../interfaces/swap/ISolidlyRouter.sol";
import {IBalancerVault} from "../interfaces/swap/IBalancerVault.sol";
import {UniV3Actions} from "../utils/UniV3Actions.sol";
import {Path} from '../utils/Path.sol';
import {BeefyBalancerStructs} from "../utils/BeefyBalancerStructs.sol";
import {BalancerActionsLib} from "../utils/BalancerActionsLib.sol";

// Additional interfaces needed 
import {IWrappedNative} from "../interfaces/IWrappedNative.sol";
import {BeefyRevenueBridgeStructs} from "./BeefyRevenueBridgeStructs.sol";

// Beefy's revenue bridging system
contract BeefyRevenueBridge is OwnableUpgradeable, BeefyRevenueBridgeStructs {
    using SafeERC20 for IERC20;
    using Address for address;
    using Path for bytes;

    IERC20 public stable;
    IERC20 public native;

    // Set our params
    bytes32 public activeBridge;
    bytes32 public activeSwap;
    BridgeParams public bridgeParams;
    SwapParams public swapParams;
    DestinationAddress public destinationAddress;

    // Will be unused if we dont swap with balancer
    IBalancerVault.SwapKind public swapKind = IBalancerVault.SwapKind.GIVEN_IN;
    IBalancerVault.FundManagement public funds;

    uint256 public minBridgeAmount;

    // Mapping our enums to function string
    mapping(bytes32 => string) public bridgeToUse;
    mapping(bytes32 => string) public swapToUse;

    /**@notice Revenue Bridge Events **/
    event SetBridge(bytes32 bridge, BridgeParams params);
    event SetSwap(bytes32 swap, SwapParams params);
    event SetMinBridgeAmount(uint256 amount);
    event SetDestinationAddress(DestinationAddress destinationAddress);
    event SetStable(address oldStable, address newStable);
    event Bridged();

    /**@notice Errors */
    error BridgeError();
    error SwapError();
    error NotAuthorized();
    error IncorrectRoute();
    error NotEnoughEth();
    error FailedToSendEther();

    function intialize(
        IERC20 _stable,
        IERC20 _native
    ) external initializer {
        __Ownable_init();

        stable = _stable;
        native = _native;

        _initBridgeMapping();
        _initSwapMapping();

        funds = IBalancerVault.FundManagement(address(this), false, payable(address(this)), false);
    }

    modifier onlyThis {
        _onlyThis();
        _;
    }

    function _onlyThis() private view {
        if (msg.sender != address(this)) revert NotAuthorized();
    }

    function _initBridgeMapping() private {
        bridgeToUse[keccak256(abi.encode("CIRCLE"))] = "bridgeCircle()";
        bridgeToUse[keccak256(abi.encode("STARGATE"))] = "bridgeStargate()";
        bridgeToUse[keccak256(abi.encode("AXELAR"))] = "bridgeAxelar()";
        bridgeToUse[keccak256(abi.encode("SYNAPSE"))] = "bridgeSynapse()";
        bridgeToUse[keccak256(abi.encode("zkEVM"))] = "bridgezkEVM()";
        bridgeToUse[keccak256(abi.encode("zkSYNC"))] = "bridgezkSync()";
    }

    function _initSwapMapping() private {
        swapToUse[keccak256(abi.encode("UNISWAP_V2"))] = "swapUniV2()";
        swapToUse[keccak256(abi.encode("SOLIDLY"))] = "swapSolidly()";
        swapToUse[keccak256(abi.encode("UNISWAP_V3"))] = "swapUniV3()";
        swapToUse[keccak256(abi.encode("UNISWAP_V3_DEADLINE"))] = "swapUniV3Deadline()";
        swapToUse[keccak256(abi.encode("BALANCER"))] = "swapBalancer()";
    }

    function harvest() external {
        _bridge();
        emit Bridged();
    }

    function _swap() private {
        address(this).functionCall(
            abi.encodeWithSignature(swapToUse[activeSwap])
        );
    }

    function _bridge() private {
        address(this).functionCall(
            abi.encodeWithSignature(bridgeToUse[activeBridge])
        );
    }

    function wrapNative() external onlyOwner {
        IWrappedNative(address(native)).deposit{value: address(this).balance}();
    }

     function inCaseTokensGetStuck(address _token, bool _native) external onlyOwner {
        if (_native) {
            uint256 _nativeAmount = address(this).balance;
            (bool sent,) = msg.sender.call{value: _nativeAmount}("");
            if(!sent) revert FailedToSendEther();
        } else {
            uint256 _amount = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(msg.sender, _amount);
        }
    }

    function setActiveBridge(bytes32 _bridgeHash, BridgeParams calldata _params) external onlyOwner {
        emit SetBridge(_bridgeHash, _params);

        _removeApprovalIfNeeded(address(stable), bridgeParams.bridge);
        
        activeBridge = _bridgeHash;
        bridgeParams = _params;

        _approveTokenIfNeeded(address(stable), _params.bridge);
    }

    function setActiveSwap(bytes32 _swapHash, SwapParams calldata _params) external onlyOwner {
        emit SetSwap(_swapHash, _params);
        _removeApprovalIfNeeded(address(native), swapParams.router);
        
        activeSwap = _swapHash;
        swapParams = _params;

        _approveTokenIfNeeded(address(native), _params.router);
    }  
    
    function setMinBridgeAmount(uint256 _amount) external onlyOwner {
       emit SetMinBridgeAmount(_amount);
       minBridgeAmount = _amount;
    }

    function setDestinationAddress(DestinationAddress calldata _destination) external onlyOwner {
        emit SetDestinationAddress(_destination);
        destinationAddress = _destination;
    }

    function setStable(IERC20 _stable) external onlyOwner {
        emit SetStable(address(stable), address(_stable));
        _removeApprovalIfNeeded(address(stable), bridgeParams.bridge);
        stable = _stable;
        _approveTokenIfNeeded(address(stable), bridgeParams.bridge);
    }

    /**@notice Bridge function called by this contract if it is the the activeBridge */
    function bridgeCircle() external onlyThis {
        uint32 destinationDomain = abi.decode(bridgeParams.params, (uint32));
        _swap();

        uint256 bal = _balanceOfStable();
        if (bal > minBridgeAmount) {
            ICircle(bridgeParams.bridge).depositForBurn(
                bal,
                destinationDomain,
                bytes32(uint256(uint160(destinationAddress.destination))),
                address(stable)
            );
        }
    }

    function bridgeStargate() external onlyThis {
        (Stargate memory _params) = abi.decode(bridgeParams.params, (Stargate));
       
        IStargate.lzTxObj memory _lzTxObj = IStargate.lzTxObj({
            dstGasForCall: _params.gasLimit,
            dstNativeAmount: 0,
            dstNativeAddr: "0x"
        });

        uint256 gasAmount = _stargateGasCost(_params.dstChainId, destinationAddress.destinationBytes, _lzTxObj);
        _getGas(gasAmount);
        _swap();
        
        uint256 stableBal = _balanceOfStable();
        if (stableBal > minBridgeAmount) {
            IStargate(bridgeParams.bridge).swap{ value: gasAmount }(
                _params.dstChainId,
                _params.srcPoolId,
                _params.dstPoolId,
                payable(address(this)),
                stableBal,
                0,
                _lzTxObj,
                destinationAddress.destinationBytes,
                ""
            );
        }
    }

    function _stargateGasCost(uint16 _dstChainId, bytes memory _dstAddress, IStargate.lzTxObj memory _lzTxObj) private view returns (uint256 gasAmount) {
        (gasAmount,) = IStargate(bridgeParams.bridge).quoteLayerZeroFee(
            _dstChainId,
            1, // TYPE_SWAP_REMOTE
            _dstAddress,
            "",
            _lzTxObj
        );
    }

    function bridgeAxelar() external onlyThis {
        Axelar memory params = abi.decode(bridgeParams.params, (Axelar));

        _swap();
        uint256 bal = _balanceOfStable();

        if (bal > minBridgeAmount) {
            IAxelar(bridgeParams.bridge).sendToken(
                params.destinationChain,
                destinationAddress.destinationString,
                params.symbol,
                bal
            );
        }
    }

    function bridgeSynapse() external onlyThis {
        (Synapse memory params) = abi.decode(bridgeParams.params, (Synapse));

        _swap();
        uint256 bal = _balanceOfStable();

        if (bal > minBridgeAmount) {
            ISynapse(bridgeParams.bridge).swapAndRedeemAndSwap(
                destinationAddress.destination,
                params.chainId,
                params.token,
                params.tokenIndexFrom,
                params.tokenIndexTo,
                bal,
                0,
                block.timestamp,
                params.dstIndexFrom,
                params.dstIndexTo,
                0,
                block.timestamp + 1 hours
            );
        }
    }

    function bridgezkEVM() external onlyThis {
        _swap();
        uint256 bal = _balanceOfStable();

        if (bal > minBridgeAmount) {
            IzkEVM(bridgeParams.bridge).send(
                destinationAddress.destination,
                address(stable),
                bal,
                1,
                uint64(block.timestamp),
                10000
            );
        }
    }

    function bridgezkSync() external onlyThis {
        _swap();
        uint256 bal = _balanceOfStable();

        if (bal > minBridgeAmount) {
            IzkSync(bridgeParams.bridge).withdraw(
                destinationAddress.destination,
                address(stable),
                bal
            );
        }
    }

    /**@notice Swap functions */
    function swapUniV2() external onlyThis {
        address[] memory route = abi.decode(swapParams.params, (address[]));
        if (route[0] != address(native)) revert IncorrectRoute();
        if (route[route.length - 1] != address(stable)) revert IncorrectRoute();
        
        uint256 bal = _balanceOfNative();
        IUniswapRouterETH(swapParams.router).swapExactTokensForTokens(
                bal, 0, route, address(this), block.timestamp
            );
    }

    function swapSolidly() external onlyThis {
        ISolidlyRouter.Routes[] memory routes = abi.decode(swapParams.params, (ISolidlyRouter.Routes[]));
        address[] memory route = _solidlyToRoute(routes);
        if (route[0] != address(native)) revert IncorrectRoute();
        if (route[route.length - 1] != address(stable)) revert IncorrectRoute();
        
        uint256 bal = _balanceOfNative();
        ISolidlyRouter(swapParams.router).swapExactTokensForTokens(bal, 0, routes, address(this), block.timestamp);
    }

    function swapUniV3() external onlyThis {
        bytes memory path = abi.decode(swapParams.params, (bytes));
        address[] memory route = _pathToRoute(path);
        if (route[0] != address(native)) revert IncorrectRoute();
        if (route[route.length - 1] != address(stable)) revert IncorrectRoute();
        
        uint256 bal = _balanceOfNative();
        UniV3Actions.swapV3(swapParams.router, path, bal);
    }

    function swapUniV3Deadline() external onlyThis {
        bytes memory path = abi.decode(swapParams.params, (bytes));
        address[] memory route = _pathToRoute(path);
        if (route[0] != address(native)) revert IncorrectRoute();
        if (route[route.length - 1] != address(stable)) revert IncorrectRoute();

        uint256 bal = _balanceOfNative();
        UniV3Actions.swapV3WithDeadline(swapParams.router, path, bal);
    }

    function swapBalancer() external onlyThis {
        (BeefyBalancerStructs.BatchSwapStruct[] memory route, address[] memory assets) = abi.decode(swapParams.params, (BeefyBalancerStructs.BatchSwapStruct[],address[]));
        if (assets[0] != address(native)) revert IncorrectRoute();
        if (assets[assets.length - 1] != address(stable)) revert IncorrectRoute();

        uint256 bal = _balanceOfNative();
        IBalancerVault.BatchSwapStep[] memory _swaps = BalancerActionsLib.buildSwapStructArray(route, bal);
        BalancerActionsLib.balancerSwap(swapParams.router, swapKind, _swaps, assets, funds, int256(bal));
    }

    /**@notice View functions */

    function _balanceOfStable() private view returns (uint256) {
        return stable.balanceOf(address(this));
    }

     function _balanceOfNative() private view returns (uint256) {
        return native.balanceOf(address(this));
    }

    function findHash(string calldata _variable) external pure returns (bytes32) {
        return keccak256(abi.encode(_variable));
    }

    // Convert encoded path to token route
    function _pathToRoute(bytes memory _path) private pure returns (address[] memory) {
        uint256 numPools = _path.numPools();
        address[] memory route = new address[](numPools + 1);
        for (uint256 i; i < numPools; i++) {
            (address tokenA, address tokenB,) = _path.decodeFirstPool();
            route[i] = tokenA;
            route[i + 1] = tokenB;
            _path = _path.skipToken();
        }
        return route;
    }

    function _solidlyToRoute(ISolidlyRouter.Routes[] memory _route) private pure returns (address[] memory) {
        address[] memory route = new address[](_route.length + 1);
        route[0] = _route[0].from;
        for (uint i; i < _route.length; ++i) {
            route[i + 1] = _route[i].to;
        }
        return route;
    }

    function _getGas(uint256 _gasAmount) private {
        _gasAmount = _gasAmount - address(this).balance;
        uint256 nativeBal = _balanceOfNative();
        if (nativeBal > _gasAmount) IWrappedNative(address(native)).withdraw(_gasAmount);
    }

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, type(uint256).max);
        }
    }

    function _removeApprovalIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) > 0) {
            IERC20(token).safeApprove(spender, 0);
        }
    }

    receive() external payable {
        assert(msg.sender == address(native));
    }
}
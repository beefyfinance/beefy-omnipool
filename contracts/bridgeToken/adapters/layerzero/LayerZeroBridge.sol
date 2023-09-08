// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; 

import "@openzeppelin-4/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IXERC20.sol";
import "../../interfaces/IXERC20Lockbox.sol";
import "./NonblockingLzApp.sol";

contract LayerZeroBridge is NonblockingLzApp {
    using SafeERC20 for IERC20;
    
    // Addresses needed
    IERC20 public BIFI;
    IXERC20 public xBIFI;
    IXERC20Lockbox public lockbox;

    uint16 private version = 1;
    uint256 public gasLimit;

    mapping (uint256 => uint16) public chainIdToLzId;
    mapping (uint16 => uint256) public lzIdToChainId;

    event BridgedOut(uint256 indexed dstChainId, address indexed bridgeUser, address indexed tokenReceiver, uint256 amount);
    event BridgedIn(uint256 indexed srcChainId, address indexed tokenReceiver, uint256 amount);

    constructor(
        IERC20 _bifi,
        IXERC20 _xbifi, 
        IXERC20Lockbox _lockbox,
        uint256 _gasLimit,
        address _endpoint
    ) NonblockingLzApp(_endpoint) {
        BIFI = _bifi;
        xBIFI = _xbifi;
        lockbox = _lockbox;
        gasLimit = _gasLimit;

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
        
        // Lock BIFI in lockbox and burn minted tokens. 
        if (address(lockbox) != address(0)) {
            BIFI.safeTransferFrom(msg.sender, address(this), _amount);
            lockbox.deposit(_amount);
            xBIFI.burn(address(this), _amount);
        } else xBIFI.burn(msg.sender, _amount);

        // Send message to receiving bridge to mint tokens to user. 
        bytes memory adapterParams = abi.encodePacked(version, gasLimit);
        bytes memory payload = abi.encode(_to, _amount);
        
         _lzSend( // {value: messageFee} will be paid out of this contract!
                chainIdToLzId[_dstChainId], // destination chainId
                payload, // abi.encode()'ed bytes
                payable(msg.sender), // (msg.sender will be this contract) refund address (LayerZero will refund any extra gas back to caller of send()
                address(0x0), // future param, unused for this example
                adapterParams, // v1 adapterParams, specify custom destination gas qty
                msg.value
        );

        emit BridgedOut(_dstChainId, msg.sender, _to, _amount);
    }

    /**@notice Estimate gas cost to bridge out funds
     * @param _dstChainId Destination chain id 
     * @param _amount Amount of BIFI to bridge out
     * @param _to Address to receive funds on destination chain
     */
    function bridgeCost(uint256 _dstChainId, uint256 _amount, address _to) external view returns (uint256 gasCost) {
        bytes memory adapterParams = abi.encodePacked(version, gasLimit);
        bytes memory payload = abi.encode(_to, _amount);
        
        (gasCost,) = lzEndpoint.estimateFees(
            chainIdToLzId[_dstChainId],
            address(this),
            payload,
            false,
            adapterParams
        );
    }

    /**@notice Add chain ids to the bridge
     * @param _chainIds Chain ids to add
     * @param _lzIds LayerZero ids to add
     */
    function addChainIds(uint256[] calldata _chainIds, uint16[] calldata _lzIds) external onlyOwner {
        for (uint i; i < _chainIds.length; ++i) {
            chainIdToLzId[_chainIds[i]] = _lzIds[i];
            lzIdToChainId[_lzIds[i]] = _chainIds[i];
        }
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory /* _srcAddress */, 
        uint64, /*_nonce*/
        bytes memory _payload
    ) internal override {
        (address user, uint256 amount) = abi.decode(_payload, (address,uint256));

        xBIFI.mint(address(this), amount);
        if (address(lockbox) != address(0)) {
            lockbox.withdraw(amount);
            BIFI.transfer(user, amount);
        } else IERC20(address(xBIFI)).transfer(user, amount); 

        emit BridgedIn(lzIdToChainId[_srcChainId], user, amount);      
    }

    function setGasLimit(uint256 _gasLimit) external onlyOwner {
        gasLimit = _gasLimit;
    }
}
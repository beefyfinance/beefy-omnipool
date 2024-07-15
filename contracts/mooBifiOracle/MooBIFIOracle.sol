// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {Initializable} from "@openzeppelin-4/contracts/proxy/utils/Initializable.sol";
import {IOptimismBridge} from "../bridgeToken/adapters/optimism/IOptimismBridge.sol";

interface IVault{
    function getPricePerFullShare() external view returns (uint256);
}

// MooBIFI Oracle via Optimism Bridge
contract MooBIFIOracle is Initializable {
    
    // Addresses needed
    IVault public vault;
    IOptimismBridge public opBridge;
    uint256 public ppfs;

    // Errors
    error WrongSender();
    error NoVault();

    // Events
    event UpdatedRate(uint256 timestamp, uint256 rate);

    // Only allow bridge to call
    modifier onlyBridge {
        _onlyBridge();
        _;
    }

    function _onlyBridge() private view {
        if (address(opBridge) != msg.sender) revert WrongSender();
        if (opBridge.xDomainMessageSender() != address(this)) revert WrongSender();
    }

    /**@notice Initialize the oracle bridge
     * @param _bridge Additional contracts needed
     */
    function initialize(
        IVault _vault,
        IOptimismBridge _bridge
    ) public initializer {
        vault = IVault(_vault);
        opBridge = IOptimismBridge(_bridge);
    }

    function update() external {
        if (address(vault) == address(0)) revert NoVault();
        uint256 rate = vault.getPricePerFullShare();
        ppfs = rate;

        bytes memory message = abi.encodeWithSignature(
            "updateOracle(uint256)",
            rate
        );

        // Send a message to our bridge counterpart which will be this contract at the same address on L2/L1. 
       opBridge.sendMessage(address(this), message, 1900000);

        emit UpdatedRate(block.timestamp, rate);
    }

    /**@notice Update the rate on the oracle
     * @param _rate Current ppfs rate on Mainnet
     */
    function updateOracle(
        uint256 _rate
    ) external onlyBridge {

        ppfs = _rate;
        emit UpdatedRate(block.timestamp, _rate);  
    }

    function getPricePerFullShare() external view returns (uint256) {
        return ppfs;
    }
}
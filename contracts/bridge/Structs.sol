// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IBalancerVault} from "../interfaces/swap/IBalancerVault.sol";

contract Structs {
    // Will be unused if we dont swap with balancer
    IBalancerVault.SwapKind public swapKind;
    IBalancerVault.FundManagement public funds;

    struct Cowllector {
        bool sendFunds;
        address cowllector;
        uint256 amountCowllectorNeeds;
    }

    struct BridgeParams {
        address bridge;
        bytes params;
    }

    struct SwapParams {
        address router;
        bytes params;
    }

    struct DestinationAddress {
        address destination;
        bytes destinationBytes;
        string destinationString;
    }

    struct Stargate {
        uint16 dstChainId;
        uint256 gasLimit;
        uint256 srcPoolId; 
        uint256 dstPoolId;
    }
    
    struct Axelar {
        string destinationChain;
        string symbol;
    }

    struct Synapse {
        uint256 chainId;
        uint8 tokenIndexFrom;
        uint8 tokenIndexTo;
        address token;
        uint8 dstIndexFrom;
        uint8 dstIndexTo;
    }

    struct Across {
        uint256 destinationChainId;
        uint256 relayFee;
    }

    struct ReAl {
        uint16 dstChainId;
    }
}
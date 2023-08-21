// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IzkEVM {
    function bridgeAsset(
        uint32 dstChainId, 
        address receiver,
        uint256 amount, 
        address token,
        bool forceUpdate,
        bytes memory permitData
        ) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IzkEVM {
    function bridgeAsset(
            uint32 destinationNetwork,
            address destinationAddress,
            uint256 amount,
            address token,
            bool forceUpdateGlobalExitRoot,
            bytes calldata permitData
        ) external payable;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReAlBridge {
     function bridgeToken(uint16 _dstChainId, address token, uint256 amount, bytes memory _adapterParams) external payable;
     function estimateFees(uint16 _dstChainId, address token, uint256 amount, bytes memory _adapterParams) external view returns (uint256, uint256);
     function getDefaultLZParam() external view returns (bytes memory);
}

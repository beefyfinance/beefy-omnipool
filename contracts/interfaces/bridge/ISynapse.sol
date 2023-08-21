// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISynapse {

    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        address token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapIndexFrom,
        uint8 swapIndexTo,
        uint256 min,
        uint256 swapTime
    ) external;
}

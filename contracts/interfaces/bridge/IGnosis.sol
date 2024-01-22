// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGnosis {
    function relayTokens (
        address token,
        address receiver,
        uint256 amount
    ) external;
}
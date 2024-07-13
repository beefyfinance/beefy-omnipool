// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILinea {
    function depositTo(
        uint256 amount,
        address to
    ) external payable;
}

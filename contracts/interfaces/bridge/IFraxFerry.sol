// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFraxFerry {
    function embarkWithRecipient(
        uint256 amount,
        address to
    ) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Errors {
     /**@notice Errors */
    error BridgeError();
    error SwapError();
    error NotAuthorized();
    error IncorrectRoute();
    error NotEnoughEth();
    error FailedToSendEther();
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Structs} from "./Structs.sol";
contract Events is Structs {
      /**@notice Revenue Bridge Events **/
    event SetBridge(bytes32 bridge, BridgeParams params);
    event SetSwap(bytes32 swap, SwapParams params);
    event SetMinBridgeAmount(uint256 amount);
    event SetDestinationAddress(DestinationAddress destinationAddress);
    event SetStable(address oldStable, address newStable);
    event Bridged(address indexed stable, uint256 stableBridged);
    event CowllectorRefill(uint256 amount);
}
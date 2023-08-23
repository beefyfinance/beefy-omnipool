// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import '@openzeppelin-4/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin-4/contracts/token/ERC20/extensions/ERC20Burnable.sol';

interface ISynapseBridge {

  function deposit(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external;

  function depositAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external;

  function redeem(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external;


  function redeemv2(
    bytes32 to,
    uint256 chainId,
    IERC20 token,
    uint256 amount
  ) external;


  function redeemAndSwap(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 tokenIndexFrom,
    uint8 tokenIndexTo,
    uint256 minDy,
    uint256 deadline
  ) external;

  function redeemAndRemove(
    address to,
    uint256 chainId,
    IERC20 token,
    uint256 amount,
    uint8 liqTokenIndex,
    uint256 liqMinAmount,
    uint256 liqDeadline
  ) external;
}
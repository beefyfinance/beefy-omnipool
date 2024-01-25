// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


interface IBeefyVault {
    function token() external view returns (address);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _shares) external;
    function withdrawAll() external;
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function want() external view returns (address);
}
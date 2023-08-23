// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "@openzeppelin-4/contracts/proxy/ERC1967/ERC1967Proxy.sol";
interface IOwnable {
    function transferOwnership(address _newOwner) external;
}

contract BeefyProxyDeployer {
    event ProxyDeployed(address indexed deployment, bytes32 salt);

    function deployNewProxy(address _implementation, bytes memory _data, bytes32 _salt) external returns (ERC1967Proxy _proxy) {
        _proxy = new ERC1967Proxy{salt: _salt}(_implementation, _data);
        emit ProxyDeployed(address(_proxy), _salt);

        try IOwnable(address(_proxy)).transferOwnership(msg.sender) {
            // Intialized as proxy deployer as owner, need to transfer this to deployer.
        } catch {
            // If it doesnt have ownable we do nothing. 
        }
    } 

    function createSalt(string memory _variable) external pure returns (bytes32 _salt) {
        return keccak256(abi.encode(_variable));
    }
}
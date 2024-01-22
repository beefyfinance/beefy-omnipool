// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IXERC20 {
    /**
     * @notice Updates the limits of any bridge
     * @dev Can only be called by the owner
     * @param _mintingLimit The updated minting limit we are setting to the bridge
     * @param _burningLimit The updated burning limit we are setting to the bridge
     * @param _bridge The address of the bridge we are setting the limits too
     */
  function setLimits(address _bridge, uint256 _mintingLimit, uint256 _burningLimit) external;

  function transferOwnership(address _owner) external;
}

contract TokenManager is OwnableUpgradeable {
    // Addresses needed
    IXERC20 public xBIFI;
    address public keeper; 

    // Events
    event SetKeeper(address indexed oldKeeper, address indexed newKeeper);
    event SetLimit(address indexed bridge, uint256 mintLimit, uint256 burnLimit);

    // Errors
    error NotAuthorized();

    modifier onlyAuth {
        _onlyAuth();
        _;
    }

    function _onlyAuth() private view {
        if (msg.sender != keeper && msg.sender != owner()) revert NotAuthorized();
    }
    function initialize(
        IXERC20 _xBIFI,
        address _keeper
    ) public initializer {
        __Ownable_init();
        xBIFI = _xBIFI;
        keeper = _keeper;
    }

    function panic(address[] calldata _bridges) external onlyAuth {
        for (uint i; i < _bridges.length; ++i) {
            _setLimit(_bridges[i], 0, 0);
        }
    }

    function setLimits(address[] calldata _bridges, uint256[] calldata _mintLimits, uint256[] calldata _burnLimits) external onlyOwner {
        for (uint i; i < _bridges.length; ++i) {
            _setLimit(_bridges[i], _mintLimits[i], _burnLimits[i]);
        }
    }

    function _setLimit(address _bridge, uint256 _mintLimit, uint256 _burnLimit) internal {
        xBIFI.setLimits(_bridge, _mintLimit, _burnLimit);
        emit SetLimit(_bridge, _mintLimit, _burnLimit);
    }

    function setKeeper(address _keeper) external onlyOwner {
        emit SetKeeper(keeper, _keeper);
        keeper = _keeper;
    }
    
    function transferOwnershipOfToken(address newOwner) external onlyOwner {
      xBIFI.transferOwnership(newOwner);
    }
}
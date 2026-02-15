// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IFacet} from "../interfaces/IFacet.sol";
import {getOwnerStorage, requireOwner, OwnerUnauthorizedAccount} from "./modules/OwnerMod.sol";

/**
 *  @title ERC-173 Contract Ownership
 */
contract OwnerFacet is IFacet {
    /**
     * @dev This emits when ownership of a contract changes.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Get the address of the owner
     * @return The address of the owner.
     */
    function owner() external view returns (address) {
        return getOwnerStorage().owner;
    }

    /**
     * @notice Set the address of the new owner of the contract
     * @dev Set _newOwner to address(0) to renounce any ownership.
     * @param _newOwner The address of the new owner of the contract
     */
    function transferOwnership(address _newOwner) external {
        OwnerStorage storage s = getOwnerStorage();
        if (msg.sender != s.owner) {
            revert OwnerUnauthorizedAccount();
        }
        address previousOwner = s.owner;
        s.owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @notice Renounce ownership of the contract
     * @dev Sets the owner to address(0), disabling all functions restricted to the owner.
     */
    function renounceOwnership() external {
        OwnerStorage storage s = getOwnerStorage();
        if (msg.sender != s.owner) {
            revert OwnerUnauthorizedAccount();
        }
        address previousOwner = s.owner;
        s.owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
          this.owner.selector,
          this.transferOwnership.selector,
          this.renounceOwnership.selector,
        );
    }
}


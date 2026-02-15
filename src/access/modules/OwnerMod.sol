// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/** 
 * @title Owner Module
 * @notice Provides internal functions and storage layout for owner management.
 * @dev Follows EIP-173 Contract Ownership Standard
 */

bytes32 constant OWNER_STORAGE_POSITION = keccak256("sapient.owner");

/**
 * @custom:storage-location erc8042:sapient.owner
 */
struct OwnerStorage {
  address owner;
}

/**
 * @notice Returns a pointer to the owner storage struct.
 * @dev Uses inline assembly to access the storage slot defined by OWNER_STORAGE_POSITION.
 * @return s The OwnerStorage struct in storage.
 */
function getOwnerStorage() pure returns (OwnerStorage storage s) {
  bytes32 position = OWNER_STORAGE_POSITION;
  assembly {
    s.slot := position
  }
}

/**
 * @notice Thrown when a non-owner attempts an action restricted to owner.
 */
error OwnerUnauthorizedAccount();

/**
 * @notice Requires the caller to be the owner of the contract
 */
function requireOwner()  view {
  if (msg.sender != getOwnerStorage().owner) {
    revert OwnerUnauthorizedAccount();
  }
}
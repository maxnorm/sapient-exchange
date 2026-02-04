// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "./diamond/DiamondMod.sol" as DiamondMod;

/**
 * @title Core
 * @notice This contract is the Core entry point for the project
 * @dev The Core contract is the Diamond Based System Core
 */
contract Core {
  constructor(address[] memory _facets) {
    // #TODO: Add facets    
  }

  fallback() external payable {
    DiamondMod.diamondFallback();
  }

  receive() external payable {}
}
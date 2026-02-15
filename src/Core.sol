// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "./diamond/modules/DiamondMod.sol" as DiamondMod;

/**
 * @title Core
 * @notice This contract is the Core entry point for the project
 * @dev The Core contract is the Diamond Based System Core
 */
contract Core {

  /**
   * @notice Initializes the diamond contract with facets, owner and other data.
   * @param _facets The facets to initialize the diamond with.
   */
  constructor(address[] memory _facets) {
      
  }

  fallback() external payable {
    DiamondMod.diamondFallback();
  }

  receive() external payable {}
}
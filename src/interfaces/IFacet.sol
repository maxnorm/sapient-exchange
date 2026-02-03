// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title IFacet
 * @notice Interface for a facet contract
 */
interface IFacet {
  function functionSelectors() external pure returns (bytes4[] memory);
}
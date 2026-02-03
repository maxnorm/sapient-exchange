// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../modules/DiamondMod.sol" as DiamondMod;
import {IFacet} from "../interfaces/IFacet.sol";

contract DiamondInspectFacet is IFacet {

  /**
   * @notice Facet struct
   * @dev Facet address
   *      Function selectors
   */
  struct Facet {
    address facet;
    bytes4[] functionSelectors;
  }
  
  /**
   *  @notice Gets the facet address that handles the given selector.
   *  @dev If facet is not found return address(0).
   *  @param _functionSelector The function selector.
   *  @return facet The facet address.
   */
  function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
    DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
    facet = s.facetNodes[_functionSelector].facet;
  }

  /**
   *  @notice Gets the function selectors that are handled by the given facet.
   *  @dev If facet is not found return empty array.
   *  @param _facet The facet address.
   *  @return facetSelectors The function selectors.
   */
  function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
    DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
    facetSelectors = IFacet(_facet).functionSelectors();
    if (facetSelectors.length == 0 || s.facetNodes[facetSelectors[0]].facet == address(0)) {
      facetSelectors = new bytes4[](0);
    }
  }

  /**
   * @notice Gets the facet addresses used by the diamond.
   *  @dev If no facets are registered return empty array.
   *  @return allFacets The facet addresses.
   */
  function facetAddresses() external view returns (address[] memory allFacets) {
    DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
    DiamondMod.FacetList memory facetList = s.facetList;
    uint256 facetCount = facetList.facetCount;
    allFacets = new address[](facetCount);
    bytes4 currentSelector = facetList.firstFacetSelector;
    for (uint256 i; i < facetCount; i++) {
      address facet = s.facetNodes[currentSelector].facet;
      allFacets[i] = facet;
      currentSelector = s.facetNodes[currentSelector].nextFacetSelector;
    }
  }

  /**
   * @notice Returns the facet address and function selectors of all facets
   *         in the diamond.
   * @dev If no facets are registered return empty array.
   * @return facetsAndSelectors An array of Facet structs containing each
   *                            facet address and its function selectors.
   */
  function facets() external view returns (Facet[] memory facetsAndSelectors) {
    DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
    DiamondMod.FacetList memory facetList = s.facetList;

    uint256 facetCount = facetList.facetCount;
    bytes4 currentSelector = facetList.firstFacetSelector;
    facetsAndSelectors = new Facet[](facetCount);
    for (uint256 i; i < facetCount; i++) {
      address facet = s.facetNodes[currentSelector].facet;
      bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
      facetsAndSelectors[i].facet = facet;
      facetsAndSelectors[i].functionSelectors = facetSelectors;
      currentSelector = s.facetNodes[currentSelector].nextFacetSelector;
    }
  }

  /**
   * @notice Returns the function selectors that are handled by this facet.
   * @return selectors The function selectors.
   */
  function functionSelectors() external pure returns (bytes4[] memory selectors) {
    selectors = new bytes4[](4);
    selectors[0] = DiamondInspectFacet.facetAddress.selector;
    selectors[1] = DiamondInspectFacet.facetFunctionSelectors.selector;
    selectors[2] = DiamondInspectFacet.facetAddresses.selector;
    selectors[3] = DiamondInspectFacet.facets.selector;
  }
}
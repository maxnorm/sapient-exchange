// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IFacet} from "../interfaces/IFacet.sol";
import {DiamondStorage, FacetList, getDiamondStorage} from "./modules/DiamondMod.sol";
import {unpackSelectors, Facet} from "./modules/DiamondInspectMod.sol";

contract DiamondInspectFacet is IFacet {
    /**
     * @notice Gets the facet address that handles the given selector.
     * @dev If facet is not found return address(0).
     * @param _functionSelector The function selector.
     * @return facet The facet address.
     */
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getDiamondStorage();
        facet = s.facetNodes[_functionSelector].facet;
    }

    /**
     * @notice Gets the function selectors that are handled by the given facet.
     * @dev If facet is not found return empty array.
     * @param _facet The facet address.
     * @return facetSelectors The function selectors.
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getDiamondStorage();
        facetSelectors = unpackSelectors(IFacet(_facet).exportSelectors());
        if (facetSelectors.length == 0 || s.facetNodes[facetSelectors[0]].facet == address(0)) {
            facetSelectors = new bytes4[](0);
        }
    }

    /**
     * @notice Gets the facet addresses used by the diamond.
     * @dev If no facets are registered return empty array.
     * @return allFacets The facet addresses.
     */
    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        allFacets = new address[](facetList.facetCount);
        bytes4 currentSelector = facetList.headFacetNodeId;
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            allFacets[i] = facet;
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
        }
    }

    /**
     * @notice Returns the facet address and function selectors of all facets
     *         in the diamond.
     * @return facetsAndSelectors An array of Facet structs containing each
     *                            facet address and its function selectors.
     */
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        bytes4 currentSelector = facetList.headFacetNodeId;
        facetsAndSelectors = new Facet[](facetList.facetCount);
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes4[] memory facetSelectors = unpackSelectors(IFacet(facet).exportSelectors());
            facetsAndSelectors[i].facet = facet;
            facetsAndSelectors[i].functionSelectors = facetSelectors;
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
        }
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            DiamondInspectFacet.facetAddress.selector,
            DiamondInspectFacet.facetFunctionSelectors.selector,
            DiamondInspectFacet.facetAddresses.selector,
            DiamondInspectFacet.facets.selector
        );
    }
}

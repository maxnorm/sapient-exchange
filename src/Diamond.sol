// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "./diamond/modules/DiamondMod.sol" as DiamondMod;
import {initOwner} from "./access/modules/OwnerMod.sol";
import {addFacets} from "./diamond/modules/DiamondUpgradeMod.sol";

/**
 * @title Core
 * @notice This contract is the Core entry point for the project
 * @dev The Core contract is the Diamond Based System Core
 */
contract Diamond {
    /**
     * @notice Initializes the diamond contract with facets, owner and other data.
     * @param _facets The facets to initialize the diamond with.
     */
    constructor(address[] memory _facets) {
        //#TODO: Add facets here
        addFacets(_facets);

        //#TODO: Set owner here
        initOwner(msg.sender);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}

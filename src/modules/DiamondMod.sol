// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/*
 * @title Diamond Module
 * @notice Internal functions and storage for diamond proxy functionality.
 * @dev Follows EIP-2535 Diamond Standard
 * (https://eips.ethereum.org/EIPS/eip-2535)
 */

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");
bytes constant FUNCTION_SELECTORS_CALL = abi.encodeWithSignature(
    "functionSelectors()"
);

/**
 * @notice The DiamondUpgradeFacet function below detects and reverts
 *         with the following errors.
 */
error NoSelectorsForFacet(address _facet);
error NoBytecodeAtAddress(address _contractAddress);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error CannotRemoveFacetThatDoesNotExist(address _facet);
error CannotReplaceFacetWithSameFacet(address _facet);
error FacetToReplaceDoesNotExist(address _oldFacet);
error FunctionSelectorsCallFailed(address _facet);
error NoFacetsToAdd();
error FunctionNotFound(bytes4 _selector);

/**
 * @dev This error means that a function to replace exists in a
 *      facet other than the facet that was given to be replaced.
 * @param _selector The function selector being replaced.
 */
error CannotReplaceFunctionFromNonReplacementFacet(bytes4 _selector);

/**
 * @notice Emitted when a function is added to a diamond.
 *
 * @param _selector The function selector being added.
 * @param _facet    The facet address that will handle calls to `_selector`.
 */
event DiamondFunctionAdded(bytes4 indexed _selector, address indexed _facet);

/**
 * @notice Emitted when changing the facet that will handle calls to a function.
 *
 * @param _selector The function selector being affected.
 * @param _oldFacet The facet address previously responsible for `_selector`.
 * @param _newFacet The facet address that will now handle calls to `_selector`.
 */
event DiamondFunctionReplaced(
    bytes4 indexed _selector,
    address indexed _oldFacet,
    address indexed _newFacet
);

/**
 * @notice Emitted when a function is removed from a diamond.
 *
 * @param _selector The function selector being removed.
 * @param _oldFacet The facet address that previously handled `_selector`.
 */
event DiamondFunctionRemoved(
    bytes4 indexed _selector,
    address indexed _oldFacet
);

/**
 * @notice Emitted when a diamond's constructor function or function from a
 *         facet makes a `delegatecall`.
 *
 * @param _delegate         The contract that was delegatecalled.
 * @param _delegateCalldata The function call, including function selector and
 *                          any arguments.
 */
event DiamondDelegateCall(address indexed _delegate, bytes _delegateCalldata);

/**
 * @notice Emitted to record information about a diamond.
 * @dev    This event records any arbitrary metadata.
 *         The format of `_tag` and `_data` are not specified by the
 *         standard.
 * @param _tag   Arbitrary metadata, such as a release version.
 * @param _data  Arbitrary metadata.
 */
event DiamondMetadata(bytes32 indexed _tag, bytes _data);

/**
 * @notice Data stored for each function selector
 * @dev Facet address of function selector
 *      Position of selector in the 'bytes4[] selectors' array
 */
struct FacetNode {
    address facet;
    bytes4 prevFacetSelector;
    bytes4 nextFacetSelector;
}

/**
 * @notice List of facets
 * @dev Number of facets
 *      First facet selector
 *      Last facet selector
 */
struct FacetList {
    uint32 facetCount;
    bytes4 firstFacetSelector;
    bytes4 lastFacetSelector;
}

/**
 * @notice This struct is used to replace old facets with new facets.
 */
struct FacetReplacement {
    address oldFacet;
    address newFacet;
}

/**
 * @custom:storage-location erc8042:erc8109.diamond
 */
struct DiamondStorage {
    mapping(bytes4 functionSelector => FacetNode) facetNodes;
    FacetList facetList;
}

function getStorage() pure returns (DiamondStorage storage s) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

// ========================================================
// Fallback Function (Diamond Entry Point)
// ========================================================

/**
 * @notice Find facet for function that is called and
 *        execute the function if a facet is found and return any value.
 */
function diamondFallback() {
    DiamondStorage storage s = getStorage();

    /* Get facet from function selector */
    address facet = s.facetNodes[msg.sig].facet;

    if (facet == address(0)) {
        revert FunctionNotFound(msg.sig);
    }

    /* Execute external function from facet using delegatecall and return any value. */
    assembly {
        /* Copy function selector and any arguments */
        calldatacopy(0, 0, calldatasize())
        /* Execute function call using the facet */
        let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
        /* Get any return value */
        returndatacopy(0, 0, returndatasize())
        /* Return any return value or error back to the caller */
        switch result
        case 0 {
            revert(0, returndatasize())
        }
        default {
            return(0, returndatasize())
        }
    }
}

/**
 * @notice Returns the function selectors for a given facet.
 * @param _facet The facet address.
 * @return selectors The function selectors.
 */
function functionSelectors(address _facet) view returns (bytes4[] memory) {
    if (_facet.code.length == 0) {
        revert NoBytecodeAtAddress(_facet);
    }

    (bool success, bytes memory data) = _facet.staticcall(
        FUNCTION_SELECTORS_CALL
    );
    if (success == false) {
        revert FunctionSelectorsCallFailed(_facet);
    }

    bytes4[] memory selectors = abi.decode(data, (bytes4[]));
    if (selectors.length == 0) {
        revert NoSelectorsForFacet(_facet);
    }

    return selectors;
}

// ========================================================
// Upgrade Diamond Function
// ========================================================

/**
 * @notice Adds facets and their function selectors to the diamond.
 */
function addFacets(address[] memory _facets) {
    uint256 facetsLength = _facets.length;

    if (facetsLength == 0) {
        revert NoFacetsToAdd();
    }

    DiamondStorage storage s = getStorage();
    FacetList memory facetList = s.facetList;

    bytes4 prev = facetList.lastFacetSelector;
    bytes4 current;

    /* Add each facet to the diamond */
    for (uint256 i; i < facetsLength; i++) {
        address facet = _facets[i];
        bytes4[] memory currentSelectors = functionSelectors(facet);
        current = currentSelectors[0];

        if (i == 0 && facetList.facetCount == 0) {
            facetList.firstFacetSelector = current;
        } else {
            s.facetNodes[prev].nextFacetSelector = current;
        }

        /* Add each selector to the diamond */
        for (
            uint256 selectorIndex;
            selectorIndex < currentSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = currentSelectors[selectorIndex];
            address oldFacet = s.facetNodes[selector].facet;

            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }

            s.facetNodes[selector] = FacetNode(facet, prev, bytes4(0));
            emit DiamondFunctionAdded(selector, facet);
        }

        prev = current;
    }

    unchecked {
        facetList.facetCount += uint32(facetsLength);
    }
    facetList.lastFacetSelector = current;
    s.facetList = facetList;
}

/**
 * @notice Replaces old facets with new facets.
 * @param _replaceFacets The old and new facets to replace.
 */
function replaceFacets(FacetReplacement[] calldata _replaceFacets) {
    DiamondStorage storage s = getStorage();
    FacetList memory facetList = s.facetList;

    for (uint256 i; i < _replaceFacets.length; i++) {
        address oldFacet = _replaceFacets[i].oldFacet;
        address newFacet = _replaceFacets[i].newFacet;

        if (oldFacet == newFacet) {
            revert CannotReplaceFacetWithSameFacet(oldFacet);
        }

        bytes4[] memory oldSelectors = functionSelectors(oldFacet);
        bytes4[] memory newSelectors = functionSelectors(newFacet);
        bytes4 oldSelector = oldSelectors[0];
        bytes4 newSelector = newSelectors[0];

        FacetNode storage firstFacetNode = s.facetNodes[oldSelector];

        if (firstFacetNode.facet != oldFacet) {
            revert FacetToReplaceDoesNotExist(oldFacet);
        }

        bytes4 prevSelector = firstFacetNode.prevFacetSelector;
        bytes4 nextSelector = firstFacetNode.nextFacetSelector;

        /* Set the facet node for the new selector. */
        s.facetNodes[newSelector] = FacetNode(
            newFacet,
            prevSelector,
            nextSelector
        );

        /* Adjust facet list if needed and emit appropriate function event */
        if (oldSelector != newSelector) {
            if (oldSelector == facetList.firstFacetSelector) {
                facetList.firstFacetSelector = newSelector;
            } else {
                s.facetNodes[prevSelector].nextFacetSelector = newSelector;
            }

            if (oldSelector == facetList.lastFacetSelector) {
                facetList.lastFacetSelector = newSelector;
            } else {
                s.facetNodes[nextSelector].prevFacetSelector = newSelector;
            }

            delete s.facetNodes[oldSelector];
            emit DiamondFunctionRemoved(oldSelector, oldFacet);
            emit DiamondFunctionAdded(newSelector, newFacet);
        } else {
            emit DiamondFunctionReplaced(newSelector, oldFacet, newFacet);
        }

        /* Add or replace new selectors. */
        for (
            uint256 selectorIndex = 1;
            selectorIndex < newSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = newSelectors[selectorIndex];
            address facet = s.facetNodes[selector].facet;
            s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
            if (facet == address(0)) {
                emit DiamondFunctionAdded(selector, newFacet);
            } else if (facet == oldFacet) {
                emit DiamondFunctionReplaced(selector, oldFacet, newFacet);
            } else {
                revert CannotReplaceFunctionFromNonReplacementFacet(selector);
            }
        }
        /**
         * Remove old selectors that were not replaced.
         */
        for (
            uint256 selectorIndex = 1;
            selectorIndex < oldSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = oldSelectors[selectorIndex];
            address facet = s.facetNodes[selector].facet;
            if (facet == oldFacet) {
                delete s.facetNodes[selector];
                emit DiamondFunctionRemoved(selector, oldFacet);
            }
        }
    }
    s.facetList = facetList;
}

function removeFacets(address[] calldata _facets) {
    DiamondStorage storage s = getStorage();
    FacetList memory facetList = s.facetList;
    for (uint256 i = 0; i < _facets.length; i++) {
        address facet = _facets[i];
        bytes4[] memory facetSelectors = functionSelectors(facet);
        bytes4 currentSelector = facetSelectors[0];
        FacetNode storage facetNode = s.facetNodes[currentSelector];
        if (facetNode.facet != facet) {
            revert CannotRemoveFacetThatDoesNotExist(facet);
        }
        /**
         * Remove the facet from the linked list.
         */
        bytes4 nextSelector = facetNode.nextFacetSelector;
        bytes4 prevSelector = facetNode.prevFacetSelector;
        if (currentSelector == facetList.firstFacetSelector) {
            facetList.firstFacetSelector = nextSelector;
        } else {
            s
                .facetNodes[facetNode.prevFacetSelector]
                .nextFacetSelector = nextSelector;
        }
        if (currentSelector == facetList.lastFacetSelector) {
            facetList.lastFacetSelector = prevSelector;
        } else {
            s.facetNodes[nextSelector].prevFacetSelector = prevSelector;
        }
        /**
         * Remove facet selectors.
         */
        for (
            uint256 selectorIndex;
            selectorIndex < facetSelectors.length;
            selectorIndex++
        ) {
            bytes4 selector = facetSelectors[selectorIndex];
            delete s.facetNodes[selector];
            emit DiamondFunctionRemoved(selector, facet);
        }
    }
    unchecked {
        facetList.facetCount -= uint32(_facets.length);
    }
    s.facetList = facetList;
}

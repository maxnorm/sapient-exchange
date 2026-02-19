// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/*
* @title Diamond Module
* @notice Module for the diamond proxy functionality.
* @dev Follows EIP-8153 Facet-Based Diamonds.
*/

import {IFacet} from "../../interfaces/IFacet.sol";

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("sapient.core.diamond");

struct FacetNode {
    address facet;
    bytes4 prevFacetNodeId;
    bytes4 nextFacetNodeId;
}

struct FacetList {
    bytes4 headFacetNodeId;
    bytes4 tailFacetNodeId;
    uint32 facetCount;
    uint32 selectorCount;
}

/**
 * @custom:storage-location erc8042:erc8109.diamond
 */
struct DiamondStorage {
    mapping(bytes4 functionSelector => FacetNode) facetNodes;
    FacetList facetList;
}

function getDiamondStorage() pure returns (DiamondStorage storage s) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Emitted when a facet is added to a diamond.
 * @dev The function selectors this facet handles can be retrieved by calling
 *      `IFacet(_facet).exportSelectors()`
 *
 * @param _facet The address of the facet that handles function calls to the diamond.
 */
event FacetAdded(address indexed _facet);

/**
 * @notice Emitted when an existing facet is replaced with a new facet.
 * @dev
 * - Selectors that are present in the new facet but not in the old facet are added to the diamond.
 * - Selectors that are present in both the new and old facet are updated to use the new facet.
 * - Selectors that are not present in the new facet but are present in the old facet are removed from
 *   the diamond.
 *
 * The function selectors handled by these facets can be retrieved by calling:
 * - `IFacet(_oldFacet).exportSelectors()`
 * - `IFacet(_newFacet).exportSelectors()`
 *
 * @param _oldFacet The address of the facet that previously handled function calls to the diamond.
 * @param _newFacet The address of the facet that now handles function calls to the diamond.
 */
event FacetReplaced(address indexed _oldFacet, address indexed _newFacet);

/**
 * @notice Emitted when a facet is removed from a diamond.
 * @dev The function selectors this facet handles can be retrieved by calling
 *      `IFacet(_facet).exportSelectors()`
 *
 * @param _facet The address of the facet that previouly handled function calls to the diamond.
 */
event FacetRemoved(address indexed _facet);

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
 *
 * @param _tag   Arbitrary metadata, such as a release version.
 * @param _data  Arbitrary metadata.
 */
event DiamondMetadata(bytes32 indexed _tag, bytes _data);

/**
 * @notice The upgradeDiamond function below detects and reverts
 *         with the following errors.
 */
error NoSelectorsForFacet(address _facet);
error NoBytecodeAtAddress(address _contractAddress);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error ExportSelectorsCallFailed(address _facet);
error IncorrectSelectorsEncoding(address _facet);

/**
 * @notice Imports the selectors that are exported by the facet.
 * @param _facet The facet address.
 * @return selectors The packed selectors.
 */
function importSelectors(address _facet) view returns (bytes memory selectors) {
    (bool success, bytes memory data) = _facet.staticcall(abi.encodeWithSelector(IFacet.exportSelectors.selector));
    if (success == false) {
        revert ExportSelectorsCallFailed(_facet);
    }

    /*
     * Ensure the data is large enough.
     * Offset (32 bytes) + array length (32 bytes)
     */
    if (data.length < 64) {
        if (_facet.code.length == 0) {
            revert NoBytecodeAtAddress(_facet);
        } else {
            revert IncorrectSelectorsEncoding(_facet);
        }
    }

    // Validate ABI offset == 0x20 for a single dynamic return
    uint256 offset;
    assembly ("memory-safe") {
        offset := mload(add(data, 0x20))
    }
    if (offset != 0x20) {
        revert IncorrectSelectorsEncoding(_facet);
    }

    /*
     * ZERO-COPY DECODE
     * Instead of abi.decode(wrapper, (bytes)), which copies memory,
     * we use assembly to point 'selectors' to the bytes array inside 'data'.
     * The length of `data` is stored at 0 and an ABI offset is located at 0x20 (32).
     * We skip over those to point `selectors` to the length of the
     * bytes array.
     */
    assembly ("memory-safe") {
        selectors := add(data, 0x40)
    }
    uint256 selectorsLength = selectors.length;
    unchecked {
        if (selectorsLength > data.length - 64) {
            revert IncorrectSelectorsEncoding(_facet);
        }
    }
    if (selectorsLength < 4) {
        revert NoSelectorsForFacet(_facet);
    }

    /*
     * Function selectors are strictly 4 bytes. We ensure the length is a multiple of 4.
     */
    if (selectorsLength % 4 != 0) {
        revert IncorrectSelectorsEncoding(_facet);
    }

    return selectors;
}

/**
 * @notice Gets the selector at the given index.
 * @param selectors The packed selectors.
 * @param index The index of the selector.
 * @return selector The 4 bytes selector.
 */
function at(bytes memory selectors, uint256 index) pure returns (bytes4 selector) {
    assembly ("memory-safe") {
        /**
         * 1. Calculate Pointer
         * add(selectors, 32) - skips the length field of the bytes array
         * shl(2, index) is the same as index * 4 but cheaper
         * This line executes: ptr = selectorsLength + (4 * index)
         */
        let ptr := add(add(selectors, 32), shl(2, index))
        /**
         * 2. Load & Return
         * We load 32 bytes, but Solidity truncates to 4 bytes automatically
         * upon return of this function, so masking is unnecessary.
         */
        selector := mload(ptr)
    }
}

//===============================================================================================================
// Diamond Fallback
//===============================================================================================================

error FunctionNotFound(bytes4 _selector);

/**
 * Find facet for function that is called and execute the
 * function if a facet is found and return any value.
 */
function diamondFallback() {
    DiamondStorage storage s = getDiamondStorage();
    /**
     * get facet from function selector
     */
    address facet = s.facetNodes[msg.sig].facet;
    if (facet == address(0)) {
        revert FunctionNotFound(msg.sig);
    }
    /*
     * Execute external function from facet using delegatecall and return any value.
     */
    assembly {
        /*
         * copy function selector and any arguments
         */
        calldatacopy(0, 0, calldatasize())
        /*
         * execute function call using the facet
         */
        let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
        /*
         * get any return value
         */
        returndatacopy(0, 0, returndatasize())
        /*
         * return any return value or error back to the caller
         */
        switch result
        case 0 {
            revert(0, returndatasize())
        }
        default {
            return(0, returndatasize())
        }
    }
}
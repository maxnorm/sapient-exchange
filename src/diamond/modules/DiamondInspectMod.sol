// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/*
* @title DiamondInspectMod
* @notice Module for inspecting the diamond.
* @dev Provides functions for inspecting the diamond.
*/

/**
 * @notice Data for each facet
 * @dev Address and function selectors
 */
struct Facet {
    address facet;
    bytes4[] functionSelectors;
}

/**
 * @notice Decodes a packed byte stream into a standard bytes4[] array.
 * @param packed The packed bytes (e.g., from `bytes.concat`).
 * @return unpacked The standard padded bytes4[] array.
 */
function unpackSelectors(bytes memory packed) pure returns (bytes4[] memory unpacked) {
    /*
     * Allocate the output array
    */
    uint256 count = packed.length / 4;
    unpacked = new bytes4[](count);
    /*
     * Copy from packed to unpacked
    */
    assembly ("memory-safe") {
        /*
         * 'src' points to the start of the data in the packed array (skip 32-byte length)
        */
        let src := add(packed, 32)
        /*
         * 'dst' points to the start of the data in the new selectors array (skip 32-byte length)
         */
        let dst := add(unpacked, 32)
        /*
         * 'end' is the stopping point for the destination pointer
         */
        let end := add(dst, mul(count, 32))
        /*
         * While 'dst' is less than 'end', keep copying
        */
        for {} lt(dst, end) {} {
            /*
             * A. Load 32 bytes from the packed source.
             *    We read "dirty" data (neighboring bytes), but it doesn't matter
             *    because we truncate it when writing.
             */
            let value := mload(src)
            /*
             * B. Clearn up the value to extract only the 4 bytes we want.
             */
            value := and(value, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
            /*
             * C. Store the value into the destination
             */
            mstore(dst, value)
            /*
             * D. Advance pointers
             */
            src := add(src, 4) // Move forward 4 bytes in packed source
            dst := add(dst, 32) // Move forward 32 bytes in destination target
        }
    }
}

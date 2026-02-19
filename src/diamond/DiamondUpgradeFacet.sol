// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IFacet} from "../interfaces/IFacet.sol";
import {DiamondStorage, FacetList, FacetNode, getDiamondStorage} from "./modules/DiamondMod.sol";
import {
    importSelectors,
    at,
    addFacets,
    replaceFacets,
    removeFacets,
    FacetReplacement
} from "./modules/DiamondUpgradeMod.sol";
import {requireOwner} from "../access/modules/OwnerMod.sol";

/**
 * @title Reference implementation for the DiamondUpgradeFacet for
 *        ERC-8153 Facet-Based Diamonds
 *
 * Security:
 * This implementation relies on the assumption that the owner of the diamond that has added or replaced any
 * facet in the diamond has verified that each facet is not malicious, that each facet is immutable (not upgradeable),
 * and that the `exportSelectors()` function in each facet is pure (is marked as a pure function and does not access state.)
 */

contract DiamondUpgradeFacet is IFacet {
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

    error NoBytecodeAtAddress(address _contractAddress);
    error DelegateCallReverted(address _delegate, bytes _delegateCalldata);

    /**
     * @notice Upgrade the diamond by adding, replacing, or removing facets.
     *
     * @dev
     * Facets are added first, then replaced, then removed.
     *
     * These events are emitted to record changes to facets:
     * - `FacetAdded(address indexed _facet)`
     * - `FacetReplaced(address indexed _oldFacet, address indexed _newFacet)`
     * - `FacetRemoved(address indexed _facet)`
     *
     * If `_delegate` is non-zero, the diamond performs a `delegatecall` to
     * `_delegate` using `_delegateCalldata`. The `DiamondDelegateCall` event is
     *  emitted.
     *
     * The `delegatecall` is done to alter a diamond's state or to
     * initialize, modify, or remove state after an upgrade.
     *
     * However, if `_delegate` is zero, no `delegatecall` is made and no
     * `DiamondDelegateCall` event is emitted.
     *
     * If _tag is non-zero or if _metadata.length > 0 then the
     * `DiamondMetadata` event is emitted.
     *
     * @param _addFacets        Facets to add.
     * @param _replaceFacets    (oldFacet, newFacet) pairs, to replace old with new.
     * @param _removeFacets     Facets to remove.
     * @param _delegate         Optional contract to delegatecall (zero address to skip).
     * @param _delegateCalldata Optional calldata to execute on `_delegate`.
     * @param _tag              Optional arbitrary metadata, such as release version.
     * @param _metadata         Optional arbitrary data.
     */
    function upgradeDiamond(
        address[] calldata _addFacets,
        FacetReplacement[] calldata _replaceFacets,
        address[] calldata _removeFacets,
        address _delegate,
        bytes calldata _delegateCalldata,
        bytes32 _tag,
        bytes calldata _metadata
    ) external {
        requireOwner();

        addFacets(_addFacets);
        replaceFacets(_replaceFacets);
        removeFacets(_removeFacets);

        if (_delegate != address(0)) {
            if (_delegate.code.length == 0) {
                revert NoBytecodeAtAddress(_delegate);
            }
            (bool success, bytes memory error) = _delegate.delegatecall(_delegateCalldata);
            if (!success) {
                if (error.length > 0) {
                    /* bubble up error */
                    assembly ("memory-safe") {
                        revert(add(error, 0x20), mload(error))
                    }
                } else {
                    revert DelegateCallReverted(_delegate, _delegateCalldata);
                }
            }
            emit DiamondDelegateCall(_delegate, _delegateCalldata);
        }

        if (_tag != 0 || _metadata.length > 0) {
            emit DiamondMetadata(_tag, _metadata);
        }
    }

    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(DiamondUpgradeFacet.upgradeDiamond.selector);
    }
}

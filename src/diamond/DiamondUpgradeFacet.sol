// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "./DiamondMod.sol" as DiamondMod;

contract DiamondUpgradeFacet {
  /**
   * @notice Thrown when a non-owner attempts an action restricted to owner.
   * @dev Only the owner can upgrade the diamond.
   */
  error OwnerUnauthorizedAccount();

  bytes32 constant OWNER_STORAGE_POSITION = keccak256("erc173.owner");

  error DelegateCallReverted(address _delegate, bytes _delegateCalldata);

  struct OwnerStorage {
    address owner;
  }
  
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
   * @notice Gets the owner storage.
   * @dev The owner storage is used to store the owner of the diamond.
   * @return s The owner storage.
   */
  function getOwnerStorage() internal pure returns (OwnerStorage storage s) {
    bytes32 position = OWNER_STORAGE_POSITION;
    assembly {
      s.slot := position
    }
  }

  /**
     * @notice Upgrade the diamond by adding, replacing, or removing facets.
     *
     * @dev
     * Facets are added first, then replaced, then removed.
     *
     * These events are emitted to record changes to functions:
     * - `DiamondFunctionAdded`
     * - `DiamondFunctionReplaced`
     * - `DiamondFunctionRemoved`
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
        DiamondMod.FacetReplacement[] calldata _replaceFacets,
        address[] calldata _removeFacets,
        address _delegate,
        bytes calldata _delegateCalldata,
        bytes32 _tag,
        bytes calldata _metadata
    ) external {
        if (getOwnerStorage().owner != msg.sender) {
            revert OwnerUnauthorizedAccount();
        }
        DiamondMod.addFacets(_addFacets);
        DiamondMod.replaceFacets(_replaceFacets);
        DiamondMod.removeFacets(_removeFacets);
        if (_delegate != address(0)) {
            if (_delegate.code.length == 0) {
                revert DiamondMod.NoBytecodeAtAddress(_delegate);
            }
            (bool success, bytes memory error) = _delegate.delegatecall(_delegateCalldata);
            if (!success) {
                if (error.length > 0) {
                    /*
                    * bubble up error
                    */
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

    function functionSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = DiamondUpgradeFacet.upgradeDiamond.selector;
    }
  
}
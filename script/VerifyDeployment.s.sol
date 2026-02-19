// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";

interface IDiamondVerify {
    function owner() external view returns (address);
    function facetAddress(bytes4 _functionSelector) external view returns (address facet);
    function facetAddresses() external view returns (address[] memory);
}

/**
 * @title VerifyDeployment
 * @notice Call the diamond to verify deployment (read-only, no broadcast).
 */
contract VerifyDeployment is Script {
    // From broadcast/Deploy.s.sol/31337/run-latest.json
    address constant DIAMOND = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;
    address constant OWNER_FACET = 0x5FbDB2315678afecb367f032d93F642f64180aa3;

    function run() public view {
        IDiamondVerify diamond = IDiamondVerify(DIAMOND);

        // 1. Diamond has code
        require(DIAMOND.code.length > 0, "Diamond has no code");

        // 2. Owner (via diamond)
        address o = diamond.owner();
        require(o != address(0), "Diamond has no owner");
        console.log("Diamond owner:", o);

        // 3. Facet list (via diamond)
        address[] memory addrs = diamond.facetAddresses();
        console.log("Facet count:", addrs.length);
        for (uint256 i; i < addrs.length; i++) {
            console.log("  facet[%s]:", i, addrs[i]);
        }

        // 4. Spot-check: owner() selector should route to OwnerFacet
        bytes4 ownerSel = 0x8da5cb5b; // owner()
        address facetForOwner = diamond.facetAddress(ownerSel);
        require(facetForOwner == OWNER_FACET, "owner() should route to OwnerFacet");
        console.log("owner() selector -> facet:", facetForOwner);

        console.log("Verification passed.");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

import {Script} from "forge-std/Script.sol";
import {Diamond} from "../src/Diamond.sol";
import {OwnerFacet} from "../src/access/OwnerFacet.sol";
import {DiamondInspectFacet} from "../src/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "../src/diamond/DiamondUpgradeFacet.sol";

contract DiamondDeployScript is Script {
    Diamond public diamond;
    OwnerFacet public ownerFacet;
    DiamondInspectFacet public diamondInspectFacet;
    DiamondUpgradeFacet public diamondUpgradeFacet;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // 1. Deploy all facets
        ownerFacet = new OwnerFacet();
        diamondInspectFacet = new DiamondInspectFacet();
        diamondUpgradeFacet = new DiamondUpgradeFacet();

        // 2. Build facet addresses for the diamond (order: Owner, Inspect, Upgrade)
        address[] memory facets = new address[](3);
        facets[0] = address(ownerFacet);
        facets[1] = address(diamondInspectFacet);
        facets[2] = address(diamondUpgradeFacet);

        // 3. Deploy the diamond with facets; constructor adds facets and sets msg.sender as owner
        diamond = new Diamond(facets);

        vm.stopBroadcast();
    }
}

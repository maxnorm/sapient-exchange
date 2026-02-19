// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {Core} from "../src/Core.sol";
import {OwnerFacet} from "../src/access/OwnerFacet.sol";
import {DiamondInspectFacet} from "../src/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "../src/diamond/DiamondUpgradeFacet.sol";

contract CoreTest is Test {
    Core public core;
    OwnerFacet public ownerFacet;
    DiamondInspectFacet public diamondInspectFacet;
    DiamondUpgradeFacet public diamondUpgradeFacet;

    address public deployer;
    address public other;

    function setUp() public {
        deployer = address(this);
        other = makeAddr("other");

        ownerFacet = new OwnerFacet();
        diamondInspectFacet = new DiamondInspectFacet();
        diamondUpgradeFacet = new DiamondUpgradeFacet();

        address[] memory facets = new address[](3);
        facets[0] = address(ownerFacet);
        facets[1] = address(diamondInspectFacet);
        facets[2] = address(diamondUpgradeFacet);

        core = new Core(facets);
    }

    function test_OwnerIsDeployer() public view {
        assertEq(OwnerFacet(address(core)).owner(), deployer);
    }

    function test_TransferOwnership() public {
        OwnerFacet(address(core)).transferOwnership(other);
        assertEq(OwnerFacet(address(core)).owner(), other);
    }

    function test_RevertWhen_NonOwnerTransfersOwnership() public {
        vm.prank(other);
        vm.expectRevert();
        OwnerFacet(address(core)).transferOwnership(other);
    }

    function test_RenounceOwnership() public {
        OwnerFacet(address(core)).renounceOwnership();
        assertEq(OwnerFacet(address(core)).owner(), address(0));
    }

    function test_FacetAddresses() public view {
        address[] memory facets_ = DiamondInspectFacet(address(core)).facetAddresses();
        assertEq(facets_.length, 3);
        assertEq(facets_[0], address(ownerFacet));
        assertEq(facets_[1], address(diamondInspectFacet));
        assertEq(facets_[2], address(diamondUpgradeFacet));
    }

    function test_ReceiveEth() public {
        (bool ok,) = address(core).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(core).balance, 1 ether);
    }
}

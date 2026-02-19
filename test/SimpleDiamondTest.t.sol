// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../src/Diamond.sol";
import {OwnerFacet} from "../src/access/OwnerFacet.sol";
import {DiamondInspectFacet} from "../src/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "../src/diamond/DiamondUpgradeFacet.sol";

contract diamondTest is Test {
    Diamond public diamond;
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

        diamond = new Diamond(facets);
    }

    function test_OwnerIsDeployer() public view {
        assertEq(OwnerFacet(address(diamond)).owner(), deployer);
    }

    function test_TransferOwnership() public {
        OwnerFacet(address(diamond)).transferOwnership(other);
        assertEq(OwnerFacet(address(diamond)).owner(), other);
    }

    function test_RevertWhen_NonOwnerTransfersOwnership() public {
        vm.prank(other);
        vm.expectRevert();
        OwnerFacet(address(diamond)).transferOwnership(other);
    }

    function test_RenounceOwnership() public {
        OwnerFacet(address(diamond)).renounceOwnership();
        assertEq(OwnerFacet(address(diamond)).owner(), address(0));
    }

    function test_FacetAddresses() public view {
        address[] memory facets_ = DiamondInspectFacet(address(diamond)).facetAddresses();
        assertEq(facets_.length, 3);
        assertEq(facets_[0], address(ownerFacet));
        assertEq(facets_[1], address(diamondInspectFacet));
        assertEq(facets_[2], address(diamondUpgradeFacet));
    }

    function test_ReceiveEth() public {
        (bool ok,) = address(diamond).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(diamond).balance, 1 ether);
    }
}

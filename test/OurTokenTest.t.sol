// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";

contract OurTokenTest is Test {
    OurToken public ourToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 100 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testTokenName() public view {
        assertEq(ourToken.name(), "OurToken");
    }

    function testTokenSymbol() public view {
        assertEq(ourToken.symbol(), "OT");
    }

    function testTokenDecimals() public view {
        assertEq(ourToken.decimals(), 18);
    }

    function testTotalSupply() public view {
        // Total supply should match what was minted in the deploy script
        assertGt(ourToken.totalSupply(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            BALANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function testBobBalance() public view {
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testZeroAddressBalance() public view {
        assertEq(ourToken.balanceOf(address(0)), 0);
    }

    function testUnknownAddressHasNoBalance() public view {
        assertEq(ourToken.balanceOf(charlie), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransfer() public {
        uint256 amount = 10 ether;
        vm.prank(bob);
        ourToken.transfer(alice, amount);

        assertEq(ourToken.balanceOf(alice), amount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - amount);
    }

    function testTransferEmitsEvent() public {
        uint256 amount = 10 ether;
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, amount);
        ourToken.transfer(alice, amount);
    }

    function testTransferZeroAmount() public {
        vm.prank(bob);
        ourToken.transfer(alice, 0);

        assertEq(ourToken.balanceOf(alice), 0);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testTransferFullBalance() public {
        vm.prank(bob);
        ourToken.transfer(alice, STARTING_BALANCE);

        assertEq(ourToken.balanceOf(alice), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(bob), 0);
    }

    function testTransferRevertsIfInsufficientBalance() public {
        uint256 tooMuch = STARTING_BALANCE + 1 ether;
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, tooMuch);
    }

    function testTransferToSelf() public {
        vm.prank(bob);
        ourToken.transfer(bob, STARTING_BALANCE);

        // Balance should remain the same after self-transfer
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
    }

    function testTransferToZeroAddressReverts() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOWANCE TESTS
    //////////////////////////////////////////////////////////////*/

    function testAllowances() public {
        uint256 initialAllowance = 1000;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        uint256 transferAmount = 500;

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    function testApproveEmitsEvent() public {
        uint256 allowance = 1000;
        vm.prank(bob);
        vm.expectEmit(true, true, false, true);
        emit Approval(bob, alice, allowance);
        ourToken.approve(alice, allowance);
    }

    function testApproveUpdatesAllowance() public {
        uint256 allowance = 500;
        vm.prank(bob);
        ourToken.approve(alice, allowance);

        assertEq(ourToken.allowance(bob, alice), allowance);
    }

    function testAllowanceDefaultsToZero() public view {
        assertEq(ourToken.allowance(bob, alice), 0);
    }

    function testApproveOverwritesPreviousAllowance() public {
        vm.startPrank(bob);
        ourToken.approve(alice, 1000);
        ourToken.approve(alice, 500); // overwrite
        vm.stopPrank();

        assertEq(ourToken.allowance(bob, alice), 500);
    }

    function testApproveZeroResetsAllowance() public {
        vm.startPrank(bob);
        ourToken.approve(alice, 1000);
        ourToken.approve(alice, 0);
        vm.stopPrank();

        assertEq(ourToken.allowance(bob, alice), 0);
    }

    function testApproveToZeroAddressReverts() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.approve(address(0), 1000);
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER FROM TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferFromReducesAllowance() public {
        uint256 allowance = 1000;
        uint256 transferAmount = 400;

        vm.prank(bob);
        ourToken.approve(alice, allowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.allowance(bob, alice), allowance - transferAmount);
    }

    function testTransferFromRevertsWithoutApproval() public {
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, 100);
    }

    function testTransferFromRevertsIfExceedsAllowance() public {
        uint256 allowance = 100;

        vm.prank(bob);
        ourToken.approve(alice, allowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, allowance + 1);
    }

    function testTransferFromRevertsIfInsufficientBalance() public {
        // Give alice a huge allowance but bob doesn't have enough tokens
        vm.prank(bob);
        ourToken.approve(alice, type(uint256).max);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, STARTING_BALANCE + 1 ether);
    }

    function testTransferFromToZeroAddressReverts() public {
        vm.prank(bob);
        ourToken.approve(alice, 1000);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, address(0), 100);
    }

    function testTransferFromEmitsTransferEvent() public {
        uint256 amount = 100;
        vm.prank(bob);
        ourToken.approve(alice, amount);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(bob, alice, amount);
        ourToken.transferFrom(bob, alice, amount);
    }

    function testTransferFromWithMaxAllowanceDoesNotReduceAllowance() public {
        // ERC20 spec: infinite allowance should not decrease
        vm.prank(bob);
        ourToken.approve(alice, type(uint256).max);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 50 ether);

        assertEq(ourToken.allowance(bob, alice), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                         MULTI-PARTY TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function testChainedTransfers() public {
        // Bob -> Alice -> Charlie
        uint256 amount = 30 ether;

        vm.prank(bob);
        ourToken.transfer(alice, amount);

        vm.prank(alice);
        ourToken.transfer(charlie, amount);

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - amount);
        assertEq(ourToken.balanceOf(alice), 0);
        assertEq(ourToken.balanceOf(charlie), amount);
    }

    function testMultipleApprovalsAndTransfers() public {
        // Bob approves both alice and charlie
        vm.startPrank(bob);
        ourToken.approve(alice, 40 ether);
        ourToken.approve(charlie, 20 ether);
        vm.stopPrank();

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 40 ether);

        vm.prank(charlie);
        ourToken.transferFrom(bob, charlie, 20 ether);

        assertEq(ourToken.balanceOf(alice), 40 ether);
        assertEq(ourToken.balanceOf(charlie), 20 ether);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - 60 ether);
    }

    /*//////////////////////////////////////////////////////////////
                         FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzzTransfer(uint256 amount) public {
        amount = bound(amount, 0, STARTING_BALANCE);

        vm.prank(bob);
        ourToken.transfer(alice, amount);

        assertEq(ourToken.balanceOf(alice), amount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - amount);
    }

    function testFuzzApproveAndTransferFrom(uint256 allowance, uint256 transferAmount) public {
        allowance = bound(allowance, 1, STARTING_BALANCE);
        transferAmount = bound(transferAmount, 1, allowance);

        vm.prank(bob);
        ourToken.approve(alice, allowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);

        // Allowance should decrease by transferAmount (unless it was max)
        if (allowance != type(uint256).max) {
            assertEq(ourToken.allowance(bob, alice), allowance - transferAmount);
        }
    }

    function testFuzzTransferDoesNotExceedSupply(uint256 amount) public {
        amount = bound(amount, STARTING_BALANCE + 1, type(uint256).max);

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, amount);
    }
}

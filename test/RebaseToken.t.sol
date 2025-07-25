// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console, Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;
    address public user = makeAddr("user");
    address public owner = makeAddr("owner");
    uint256 public SEND_VALUE = 1e5;

    function addRewardsToVault(uint256 amount) public {
        // send some rewards to the vault using the receive function
        payable(address(vault)).call{value: amount}("");
    }

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        // (bool success,) = payable(address(vault)).call{value: 1e8}("");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        // Deposit funds
        amount = bound(amount, 1e5, type(uint96).max); //  min + (input % (max - min + 1))
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(amount, startBalance);
        // 3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("endBalance", endBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testdeposit(uint256 amount) public {
        amount = bound(amount, 1e3, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
    }

    function testCannotWithdrawMoreThanBalance() public {
        // Deposit funds
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        vm.expectRevert();
        vault.redeem(SEND_VALUE + 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max); //  min + (input % (max - min + 1))
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        // Redeem funds
        vault.redeem(amount);
        uint256 balance = rebaseToken.balanceOf(user);
        console.log("User balance: ", balance);
        assertEq(balance, 0);
        assertEq(address(user).balance, amount);
        console.log("User balance: ", address(user).balance);
        vm.stopPrank();
    }

    function testRedeemAfterTimeHasPassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000 seconds, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot. 1000 + (time % (max - 1000 + 1))
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); //  min + (input % (max - min + 1)).  this is an Ether value of max 2^78 which is crazy
        // Deposit funds
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // check the balance has increased after some time has passed
        vm.warp(time);

        // Get balance after time has passed
        uint256 balance = rebaseToken.balanceOf(user);

        // Add rewards to the vault
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);

        // Redeem funds
        vm.prank(user);
        vault.redeem(balance);

        uint256 ethBalance = address(user).balance;

        assertEq(balance, ethBalance);
        assertGt(balance, depositAmount);
    }

    function testRedeemFailsWhenTransferFails(uint256 amount) public {
        // Setup
        amount = bound(amount, 1e5, type(uint96).max);
        RevertingReceiver receiver = new RevertingReceiver();

        vm.deal(address(receiver), amount);

        vm.prank(address(receiver));
        vault.deposit{value: amount}();

        vm.startPrank(address(receiver));
        vm.expectRevert(Vault.Vault__RedeemFailed.selector);
        vault.redeem(amount);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e3, type(uint96).max); //  min + (input % (max - min + 1))
        amountToSend = bound(amountToSend, 1e5, amount - 1e3); //  min + (input % (max - min + 1))

        // Deposit funds
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address userTwo = makeAddr("userTwo");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 userTwoBalance = rebaseToken.balanceOf(userTwo);
        assertEq(userBalance, amount);
        assertEq(userTwoBalance, 0);
        // Update the interest rate so we can check the user interest rates are different after transferring.
        vm.prank(owner);
        // decrease the interest rate to 4e10
        rebaseToken.setInterestRate(4e10);

        // Send half the balance to another user
        vm.prank(user);
        rebaseToken.transfer(userTwo, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 userTwoBalancAfterTransfer = rebaseToken.balanceOf(userTwo);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(userTwoBalancAfterTransfer, userTwoBalance + amountToSend);

        // After some time has passed, check the balance of the two users has increased
        vm.warp(block.timestamp + 1 days);
        uint256 userBalanceAfterWarp = rebaseToken.balanceOf(user);
        uint256 userTwoBalanceAfterWarp = rebaseToken.balanceOf(userTwo);

        // check their interest rates are as expected
        // since user two hadn't minted before, their interest rate should be the same as in the contract
        uint256 userTwoInterestRate = rebaseToken.getUserInterestRate(userTwo);
        assertEq(userTwoInterestRate, 5e10);
        // since user had minted before, their interest rate should be the previous interest rate
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        assertEq(userInterestRate, 5e10);

        assertGt(userBalanceAfterWarp, userBalanceAfterTransfer);
        assertGt(userTwoBalanceAfterWarp, userTwoBalancAfterTransfer);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        // Update the interest rate
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        rebaseToken.setInterestRate(newInterestRate);
        vm.stopPrank();
    }

    function testCannotCallMintAndBurn() public {
        vm.startPrank(user);
        uint256 interestRate = rebaseToken.getInterestRate();

        // First restricted call - mint
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.mint(user, 100, interestRate);

        // Second restricted call - burn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, keccak256("MINT_AND_BURN_ROLE")
            )
        );
        rebaseToken.burn(user, 100);

        vm.stopPrank();
    }

    function testSetInterestRate(uint256 newInterestRate) public {
        // bound the interest rate to be less than the current interest rate
        newInterestRate = bound(newInterestRate, 0, rebaseToken.getInterestRate() - 1);
        // Update the interest rate
        vm.startPrank(owner);
        rebaseToken.setInterestRate(newInterestRate);
        uint256 interestRate = rebaseToken.getInterestRate();
        assertEq(interestRate, newInterestRate);
        vm.stopPrank();

        // check that if someone deposits, this is their new interest rate
        vm.startPrank(user);
        vm.deal(user, SEND_VALUE);
        vault.deposit{value: SEND_VALUE}();
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        vm.stopPrank();
        assertEq(userInterestRate, newInterestRate);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.prank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 principalAmount = rebaseToken.principalBalanceOf(user);
        assertEq(principalAmount, amount);
        // check that the principle amount is the same after some time has passed
        vm.warp(block.timestamp + 1 days);
        uint256 principleAmountAfterWarp = rebaseToken.principalBalanceOf(user);
        assertEq(principleAmountAfterWarp, amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(address(vault.getRebaseTokenAddress()), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(bytes4(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector));
        rebaseToken.setInterestRate(newInterestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }

    function testCannotSetInterestRateIfNotOwner() public {
        // Update the interest rate
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        rebaseToken.setInterestRate(1e10);
        vm.stopPrank();
    }
}

contract RevertingReceiver {
    receive() external payable {
        revert("Transfer failed");
    }
}

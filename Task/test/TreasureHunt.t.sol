// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {TreasureHunt} from "../src/TreasureHunt.sol";

contract TreasureHuntTest is Test {
    TreasureHunt public treasureHunt;

    address public owner = address(this);
    address public player1 = address(0x1);
    address public player2 = address(0x2);
    address public player3 = address(0x3);

    uint256 public initialReward = 1 ether;
    uint256 public joinFee = 0.1 ether;



    function setUp() public {
        treasureHunt = new TreasureHunt();
        treasureHunt.initialize(initialReward);
        vm.label(owner, "Owner");
        vm.label(player1, "Player1");
        vm.label(player2, "Player2");
        vm.label(player3, "Player3");
    }

    /// @notice Test that the contract is deployed correctly with initial settings
    function testDeployment() public {
        assertEq(address(treasureHunt).balance, initialReward, "Initial reward not set correctly");
        assertEq(treasureHunt.isGameActive(), true, "Game should be active upon deployment");
        assertEq(treasureHunt.gameRound(), 1, "Initial game round should be 1");
        uint8 treasurePosition = treasureHunt.treasurePosition();
        assertTrue(treasurePosition <= 99, "Treasure position should be within grid limits");
        console.log("Initial treasure position:", treasurePosition);
    }

    /// @notice Test that a player can join the game successfully
    function testPlayerJoinGame() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        (uint8 position, uint256 score) = treasureHunt.players(player1);
        assertTrue(position <= 99, "Player position should be within grid limits");
        assertEq(score, 0, "Player score should be initialized to 0");
        assertEq(address(treasureHunt).balance, initialReward + joinFee, "Contract balance should increase by join fee");
        console.log("Player1 joined at position:", position);
    }

    /// @notice Test that player movement works correctly
    function testPlayerMovement() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        (uint8 startPosition, ) = treasureHunt.players(player1);
        uint8 newPosition = getAdjacentPosition(startPosition);
        vm.prank(player1);
        treasureHunt.move(newPosition);
        (uint8 currentPosition, ) = treasureHunt.players(player1);
        assertEq(currentPosition, newPosition, "Player should have moved to the new position");
        console.log("Player1 moved from", startPosition, "to", newPosition);
    }

    /// @notice Test treasure movement when player moves to multiple of 5 position
    function testTreasureMovementOnMultipleOfFive() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        vm.startPrank(player1);
        uint8 multipleOfFivePosition = 10;
        setPlayerPosition(player1, multipleOfFivePosition);
        uint8 initialTreasurePosition = treasureHunt.treasurePosition();
        treasureHunt.move(multipleOfFivePosition);
        uint8 newTreasurePosition = treasureHunt.treasurePosition();
        assertTrue(isAdjacent(initialTreasurePosition, newTreasurePosition), "Treasure should have moved to adjacent position");
        vm.stopPrank();
    }

    /// @notice Test treasure movement when player moves to prime number position
    function testTreasureMovementOnPrimeNumber() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        vm.startPrank(player1);
        uint8 primePosition = 7;
        setPlayerPosition(player1, primePosition);
        treasureHunt.move(primePosition);
        uint8 newTreasurePosition = treasureHunt.treasurePosition();
        assertTrue(newTreasurePosition <= 99, "Treasure should have moved to a random position within grid");
        console.log("Treasure moved to", newTreasurePosition, "due to prime number rule");
        vm.stopPrank();
    }

    /// @notice Test winning scenario and ETH distribution
    function testWinningScenario() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        (uint8 playerPosition, ) = treasureHunt.players(player1);
        uint8 treasurePosition = treasureHunt.treasurePosition();
        vm.startPrank(player1);
        setPlayerPosition(player1, treasurePosition);
        uint256 contractBalanceBefore = address(treasureHunt).balance;
        uint256 playerBalanceBefore = player1.balance;
        treasureHunt.move(treasurePosition);
        uint256 reward = (contractBalanceBefore * 90) / 100;
        uint256 contractBalanceAfter = address(treasureHunt).balance;
        uint256 playerBalanceAfter = player1.balance;
        assertEq(playerBalanceAfter, playerBalanceBefore + reward, "Player should receive correct reward");
        assertEq(contractBalanceAfter, contractBalanceBefore - reward, "Contract balance should be reduced by reward amount");
        console.log("Player1 won and received", reward, "wei");
        vm.stopPrank();
    }

    /// @notice Test multiple players joining and playing the game
    function testMultiplePlayers() public {
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);
        vm.deal(player3, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        vm.prank(player2);
        treasureHunt.joinGame{value: joinFee}();
        vm.prank(player3);
        treasureHunt.joinGame{value: joinFee}();
        (uint8 pos1, ) = treasureHunt.players(player1);
        (uint8 pos2, ) = treasureHunt.players(player2);
        (uint8 pos3, ) = treasureHunt.players(player3);
        assertTrue(pos1 != pos2 && pos2 != pos3 && pos1 != pos3, "Players should have different starting positions");
        console.log("Player positions:", pos1, pos2, pos3);
        vm.prank(player1);
        treasureHunt.move(getAdjacentPosition(pos1));
        vm.prank(player2);
        treasureHunt.move(getAdjacentPosition(pos2));
        vm.prank(player3);
        treasureHunt.move(getAdjacentPosition(pos3));
        console.log("Multiple players moved successfully without conflicts");
    }

    /// @notice Test that player cannot join twice in the same round
    function testDoubleJoinNotAllowed() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        vm.prank(player1);
        vm.expectRevert("Already joined this round");
        treasureHunt.joinGame{value: joinFee}();
    }

    /// @notice Test that player cannot move to non-adjacent position
    function testInvalidMovement() public {
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
        (uint8 startPosition, ) = treasureHunt.players(player1);
        uint8 invalidPosition = startPosition + 10;
        vm.prank(player1);
        vm.expectRevert("Invalid move");
        treasureHunt.move(invalidPosition);
    }

    /// @notice Test pausing and resuming the game
    function testPauseAndResumeGame() public {
        treasureHunt.pauseGame();
        assertEq(treasureHunt.isGameActive(), false, "Game should be paused");
        vm.deal(player1, 1 ether);
        vm.prank(player1);
        vm.expectRevert("Game is not active");
        treasureHunt.joinGame{value: joinFee}();
        treasureHunt.resumeGame();
        assertEq(treasureHunt.isGameActive(), true, "Game should be active");
        vm.prank(player1);
        treasureHunt.joinGame{value: joinFee}();
    }

    /// @notice Test owner withdrawing funds
    function testOwnerWithdraw() public {
        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalance = address(treasureHunt).balance;
        treasureHunt.withdraw();
        uint256 ownerBalanceAfter = owner.balance;
        uint256 contractBalanceAfter = address(treasureHunt).balance;
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractBalance, "Owner should have withdrawn all funds");
        assertEq(contractBalanceAfter, 0, "Contract balance should be zero after withdrawal");
    }

    /// @notice Helper function to get an adjacent position
    function getAdjacentPosition(uint8 position) internal pure returns (uint8) {
        if (position % 10 < 9) {
            return position + 1; 
        } else if (position % 10 > 0) {
            return position - 1; 
        } else if (position / 10 < 9) {
            return position + 10; 
        } else {
            return position - 10; 
        }
    }

    /// @notice Helper function to set player position directly for testing
function setPlayerPosition(address player, uint8 position) internal {
    treasureHunt.SetPlayerPosition(player, position);
}

    /// @notice Helper function to check if two positions are adjacent
    function isAdjacent(uint8 pos1, uint8 pos2) internal pure returns (bool) {
        int8 diff = int8(pos1) - int8(pos2);
        return diff == 1 || diff == -1 || diff == 10 || diff == -10;
    }

}

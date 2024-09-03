// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions
// Layout of Functions:
// constructor
// receive function 
// fallback function 
// external
// public
// internal
// private
// view & pure functions




// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

///////////////////
// import
///////////////////
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title Treasure Hunt Game
/// @notice This contract allows multiple players to participate in a treasure hunt on a 10x10 grid.
/// Game Rounds: Allow multiple game rounds without redeploying the contract.
/// Track player statistics across multiple rounds.
/// Allow for dynamic grid size and reward distribution adjustments.
/// Admin Controls: Allow an admin to pause or restart the game.
contract TreasureHunt  is UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    
    ///////////////////
    // State Variables
    ///////////////////
    uint8 public constant gridSize = 10; 
    uint8 public constant gridMax = gridSize * gridSize - 1;  
    uint256 public initialTreasureReward;

    struct Player {
        uint8 position;  
        uint256 score;   
    }

    mapping(address => Player) public players;  
    uint8 public treasurePosition;  
    uint256 public roundBalance;   
    address public winner;    
    uint256 public gameRound; 
    bool public isGameActive; 
    uint8[4] public adjacents;
    

    ///////////////////
    // Events
    ///////////////////
    event PlayerMoved(address indexed player, uint8 indexed newPosition);
    event TreasureMoved(uint8 indexed newPosition);
    event GameWon(address indexed winner, uint256 reward);
    event NewRoundStarted(uint256 indexed gameRound);
    event GamePaused();
    event GameResumed();

    ///////////////////
    // modifier
    ///////////////////
    modifier onlyActiveGame() {
        require(isGameActive, "Game is not active");
        _;
    }

   ///////////////////
   // Functions
   ///////////////////
    function initialize(uint256 _initialTreasureReward) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();
        initialTreasureReward = _initialTreasureReward;
        startNewRound();
    }


    ////////////////////////////
    // External Functions
    ////////////////////////////

    /// @notice Allows a player to join the game by sending ETH.
    /// @dev The player's starting position is determined randomly.
    function joinGame() external payable whenNotPaused nonReentrant {
        require(msg.value > 0, "Must send ETH to join");
        require(players[msg.sender].position == 0, "Already joined this round");
        players[msg.sender].position = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % gridMax);
        roundBalance += msg.value;
    }

    /// @notice Allows a player to move to a new position on the grid.
    /// @dev Checks if the move is valid and updates the player's position. If the player finds the treasure, they win the round.
    /// @param newPosition The new position the player wants to move to.
     function move(uint8 newPosition) external whenNotPaused nonReentrant  {
        Player storage player = players[msg.sender];
        require(player.position != 0, "Not a participant");
        require(isAdjacent(player.position, newPosition), "Invalid move");
        player.position = newPosition;
        emit PlayerMoved(msg.sender, newPosition);
        if (newPosition == treasurePosition) {
            player.score++;
             uint256 reward = (roundBalance * 90) / 100 + initialTreasureReward;
            payable(msg.sender).transfer(reward);
            emit GameWon(msg.sender, reward);
            startNewRound();
        } else {
            moveTreasure(newPosition);
        }
    }

     // Function to set a player's position for testing
    function SetPlayerPosition(address player, uint8 newPosition) public {
        players[player].position = newPosition;
    }


    ////////////////////////////
    // Internal Functions
    ////////////////////////////

    /// @notice Moves the treasure based on the player's new position.
    /// @dev The treasure moves randomly if the player lands on a multiple of 5 or a prime number.
    /// @param playerPosition The position of the player after their move.
     function moveTreasure(uint8 playerPosition) internal {
        if (playerPosition % 5 == 0) {
            treasurePosition = getRandomAdjacent(treasurePosition);
        } else if (isPrime(playerPosition)) {
            treasurePosition = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % gridMax);
        }
        emit TreasureMoved(treasurePosition);
    }


    /// @notice Generates a random adjacent position to the given position.
    /// @dev This is a pseudo-random function; for better randomness, Chainlink VRF should be used.
    /// @param pos The current position.
    /// @return A new adjacent position.
     function getRandomAdjacent(uint8 pos) internal  returns (uint8) {
        uint8;
        uint8 count = 0;
        if (pos >= gridSize) adjacents[count++] = pos - gridSize;
        if (pos < gridMax - gridSize) adjacents[count++] = pos + gridSize;
        if (pos % gridSize != 0) adjacents[count++] = pos - 1;
        if (pos % gridSize != gridSize - 1) adjacents[count++] = pos + 1;
        return adjacents[uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, pos))) % count)];
    }


    /// @notice Checks if a number is prime.
    /// @dev Used to determine if a player lands on a prime-numbered grid position.
    /// @param number The number to check.
    /// @return True if the number is prime, false otherwise.
    function isPrime(uint8 number) internal pure returns (bool) {
    if (number < 2) return false;
    for (uint8 i = 2; i * i <= number; i++) {
        if (number % i == 0) return false;
    }
    return true;
    }



     /// @notice Checks if two positions are adjacent on the grid.
    /// @param pos1 The first position.
    /// @param pos2 The second position.
    /// @return True if the positions are adjacent, false otherwise.
    function isAdjacent(uint8 pos1, uint8 pos2) internal pure returns (bool) {
        int8 diff = int8(pos1) - int8(pos2);
        return diff == 1 || diff == -1 || diff == int8(gridSize) || diff == -int8(gridSize);
    }


    /// @notice Starts a new round of the game.
    /// @dev Resets the game state and randomly places the treasure in a new position.
    function startNewRound() internal {
        treasurePosition = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % gridMax);
        roundBalance = 0;
        gameRound++;
        isGameActive = true;
        emit NewRoundStarted(gameRound);
    }

      /// @notice Pauses the game, preventing further actions.
    function pauseGame() external onlyOwner {
        _pause();
    }

    /// @notice Resumes the game after being paused.
    function resumeGame() external onlyOwner {
        _unpause();
    }

    /// @notice Withdraws the balance of the contract to the owner.
    function withdraw() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    

     /// @notice Authorizes the upgrade of the contract.
    /// @param newImplementation The new implementation address.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}
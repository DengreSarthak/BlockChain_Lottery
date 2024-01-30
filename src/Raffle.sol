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
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// Function starting always (CEI)--- check , effects, interactions
//                             check(require or if()then revert)
//                             effects()

// -------------------------------------------------------------------------------------------

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle_NotEnoughEth();
    error Raffle_TransactionFailed();
    error Raffle_RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 currBalance,
        uint256 numPlayers,
        RaffleState Rafflestate
    );

    // Type declearation
    enum RaffleState {
        open,
        calculting
    }

    // State variables
    uint256 private immutable i_entryfee;
    uint256 private immutable i_interval;

    VRFCoordinatorV2Interface private immutable i_vrfCordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_suscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant s_requestConfirmations = 3;
    uint32 private constant s_numWords = 1;
    uint256 private s_lastTimeStamp;
    address payable[] private s_participants;
    address private s_recentWinner;
    RaffleState private s_RaffleState;

    // Events
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entryfee,
        uint256 interval,
        address vrfCordinator,
        bytes32 gasLane, // 30 gwie key hash
        uint64 suscripitonId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCordinator) {
        i_entryfee = entryfee;
        i_interval = interval;
        i_vrfCordinator = VRFCoordinatorV2Interface(vrfCordinator);
        i_gasLane = gasLane;
        i_suscriptionId = suscripitonId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_RaffleState = RaffleState.open;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entryfee) {
            revert Raffle_NotEnoughEth();
        }
        if (s_RaffleState == RaffleState.calculting)
            revert Raffle_RaffleNotOpen();

        s_participants.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = RaffleState.open == s_RaffleState;
        bool hasPlayers = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0"); //"0x0" null space
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                s_RaffleState
            );
        }

        s_RaffleState = RaffleState.calculting;
        uint256 requestId = i_vrfCordinator.requestRandomWords(
            i_gasLane,
            i_suscriptionId,
            s_requestConfirmations,
            i_callbackGasLimit,
            s_numWords
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // check

        //effects
        uint256 indexOfWinner = randomWords[0] % 10;
        address payable winner = s_participants[indexOfWinner];
        s_recentWinner = winner;
        s_lastTimeStamp = block.timestamp;
        s_participants = new address payable[](0);
        s_RaffleState = RaffleState.open;
        emit PickedWinner(winner);
        // interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransactionFailed();
        }
    }

    function getEntryfee() external view returns (uint256) {
        return i_entryfee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_RaffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_participants[indexOfPlayer];
    }

    function getWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getNumberOfParticipants() external view returns (uint256) {
        return s_participants.length;
    }

    function getLastTimestamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }
}

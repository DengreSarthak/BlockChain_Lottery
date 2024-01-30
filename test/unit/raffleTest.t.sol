//SPDX-License-Identifier: MIT

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

pragma solidity ^0.8.18;

contract raffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);

    uint256 entryfee;
    uint256 interval;
    address vrfCordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerUint;

    HelperConfig helperConfig;
    Raffle raffle;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entryfee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipfork() {                               // to skip test when we are pretending to be vrfcordinator
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            entryfee,
            interval,
            vrfCordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.open);
    }

    function testRaffleRevertsWhenNotEnoughSent() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        raffle.enterRaffle{value: entryfee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entryfee}();
    }

    function testCantEnterRaffleWhenCalculating()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entryfee}();
    }

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entryfee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsTrueIfRaffleClose()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");

        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfAllParametersGood()
        public
        raffleEnteredAndTimePassed
    {
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        assert(upKeepNeeded);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
    }

    function testPerformupkeepRevertIfCheckupkeepFalse() public skipfork {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    // Testing on the basis of output of an event
    function testPerformUpKeepUpdatesRaffleStateAndEmitRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    function testFulfilRandomWordsCallOnlyAfterPerformUpKeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipfork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipfork
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        uint256 prize = (additionalEntrants + 1) * entryfee;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entryfee}();
        }

        uint256 previousTimeStamp = raffle.getLastTimestamp();

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // pretending to be chianlink vrf to get random number and pick winner
        VRFCoordinatorV2Mock(vrfCordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getNumberOfParticipants() == 0);
        assert(raffle.getWinner() != address(0));
        assert(previousTimeStamp < raffle.getLastTimestamp());
        assert(
            raffle.getWinner().balance ==
                STARTING_USER_BALANCE + prize - entryfee
        );
    }
}

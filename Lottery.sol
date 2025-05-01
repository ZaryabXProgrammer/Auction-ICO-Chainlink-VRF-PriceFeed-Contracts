// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Chainlink VRF v2.5 imports
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

// Chainlink AggregatorV3Interface import
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// OpenZeppelin Ownable contract - using direct import instead of aggregated


contract Lottery is VRFConsumerBaseV2Plus {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lottery_state;

    IVRFCoordinatorV2Plus private vrfCoordinator;

    uint256 private subscriptionId;
    bytes32 private keyHash;
    uint32 private callbackGasLimit;
    uint16 private requestConfirmations;
    uint32 private numWords;

    event RequestedRandomness(uint256 requestId);
    event WinnerPicked(address winner);

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
      
        
        usdEntryFee = 5 * 10**18;
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;

        vrfCoordinator = IVRFCoordinatorV2Plus(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = 3;
        numWords = 1;
    }
    
    function enter() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN, "Lottery is not open");
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(payable(msg.sender));
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        return (usdEntryFee * 10**18) / adjustedPrice;
    }

    function startLottery() public  {
        require(lottery_state == LOTTERY_STATE.CLOSED, "Already started");
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public  {
        require(lottery_state == LOTTERY_STATE.OPEN, "Lottery not open");
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: keyHash,
            subId: subscriptionId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({ nativePayment: true })
            )
        });

        uint256 requestId = vrfCoordinator.requestRandomWords(req);
        emit RequestedRandomness(requestId);
    }

    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "Not ready");
        require(randomWords[0] > 0, "Random number not found");

        uint256 indexOfWinner = randomWords[0] % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);

        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = randomWords[0];

        emit WinnerPicked(recentWinner);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts@1.3.0/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error NotOwner();

contract FundMe {
    AggregatorV3Interface internal dataFeed;

    // This is the minimum USD value (in 18 decimal format) required to allow funding — here it's set to $5
    uint256 public minimumUsd = 5 * 1e18;
    address public immutable i_owner;

    /**
     * Network: Sepolia
     * Aggregator: ETH/USD
     * Address: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     */
    constructor() {
        // Setting up the ETH/USD price feed from Chainlink
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    /**
     * Function to receive ETH from users
     * It checks whether the amount sent is worth at least $5 (converted using live ETH/USD rate)
     */
    function fund() public payable {
        // Check if the ETH sent is worth at least $5
        // getConversionRate(msg.value) will convert the sent ETH to USD
        require(
            getConversionRate(msg.value) >= minimumUsd,
            "Didn't send enough ETH"
        );
    }

    /**
     * Gets the latest ETH price in USD
     */
    function getPrice() public view returns (uint256) {
        (
            ,
            // roundId not used
            int256 answer, // This is the price value, like 2000.00000000 (8 decimal places) // startedAt not used // updatedAt not used
            ,
            ,

        ) = // answeredInRound not used
            dataFeed.latestRoundData();

        // Convert price from 8 decimals to 18 decimals to match wei format
        // e.g., if answer = 2000.00000000 => 200000000000
        // 200000000000 * 1e10 = 2000000000000000000000 (now it has 18 decimals)
        return uint256(answer * 1e10); // This gives price in 18 decimal format
    }

    /**
     * Converts ETH amount to USD based on the current price
     */
    function getConversionRate(uint256 ethAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        // ethPrice is now something like 2000 * 1e18 = 2000000000000000000000

        // Multiply ETH price with the amount of ETH sent
        // Example: if ethAmount = 1 ETH = 1e18 wei
        // Then ethPrice * ethAmount = 2000e18 * 1e18 = 2000e36

        // Divide by 1e18 to convert back to normal USD scale (still in 18 decimals)
        // Final result: 2000e36 / 1e18 = 2000e18 => $2000 in 18 decimal format
        uint256 ethAmountInUSD = (ethPrice * ethAmount) / 1e18;

        return ethAmountInUSD;
    }

    /**
     * Returns the version of Chainlink Aggregator being used
     */
    function getVersion() public view onlyOwner returns  (uint256)  {
        return dataFeed.version();
    }
}

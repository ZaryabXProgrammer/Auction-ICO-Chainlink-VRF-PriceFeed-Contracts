// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract DutchAuction {
    // Auction settings
    IERC721 public immutable nft;
    uint256 public immutable nftId;
    uint256 public immutable startingPrice;
    uint256 public immutable reservePrice;
    uint256 public immutable duration;
    address payable public immutable seller;

    // Auction state
    uint256 public startAt;
    uint256 public endAt;
    bool public started;
    bool public sold;

    error AuctionAlreadyStarted();
    error AuctionNotStarted();
    error AuctionEnded();
    error AuctionAlreadySold();
    error InvalidPayment();

    event AuctionStarted();
    event NFTBought(address buyer, uint256 price);
    event AuctionEndedWithoutSale();

    constructor(
        address _nft,
        uint256 _nftId,
        uint256 _startingPrice,
        uint256 _reservePrice,
        uint256 _duration // duration in seconds
    ) {
        require(
            _startingPrice > _reservePrice,
            "Start price must be > reserve"
        );

        nft = IERC721(_nft);
        nftId = _nftId;
        startingPrice = _startingPrice;
        reservePrice = _reservePrice;
        duration = _duration;
        seller = payable(msg.sender);
    }

    function start() external {
        if (started) revert AuctionAlreadyStarted();
        require(msg.sender == seller, "Only seller can start");

        nft.transferFrom(seller, address(this), nftId);
        startAt = block.timestamp;
        endAt = block.timestamp + duration;
        started = true;

        emit AuctionStarted();
    }

    function getCurrentPrice() public view returns (uint256) {
        if (!started) revert AuctionNotStarted();

        uint256 elapsed = block.timestamp - startAt;
        if (elapsed >= duration) return reservePrice;

        uint256 discount = ((startingPrice - reservePrice) * elapsed) /
            duration;
        return startingPrice - discount;
    }

    function buy() external payable {
        if (!started) revert AuctionNotStarted();
        if (block.timestamp > endAt) revert AuctionEnded();
        if (sold) revert AuctionAlreadySold();

        uint256 currentPrice = getCurrentPrice();
        if (msg.value < currentPrice) revert InvalidPayment();

        sold = true;

        nft.transferFrom(address(this), msg.sender, nftId);
        seller.transfer(currentPrice);

        // Refund extra ETH sent
        if (msg.value > currentPrice) {
            payable(msg.sender).transfer(msg.value - currentPrice);
        }

        emit NFTBought(msg.sender, currentPrice);
    }

    function endAuctionWithoutSale() external {
        if (!started) revert AuctionNotStarted();
        if (block.timestamp < endAt) revert AuctionEnded();
        if (sold) revert AuctionAlreadySold();
        require(msg.sender == seller, "Only seller can end");

        nft.transferFrom(address(this), seller, nftId);
        sold = true;

        emit AuctionEndedWithoutSale();
    }
}

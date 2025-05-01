// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

error NotStarted();
error AlreadyStarted();
error AlreadyEnded();
error NotEnded();
error NotSeller();
error BidTooLow();
error NoFundsToWithdraw();

contract EnglishAuction is Ownable, ReentrancyGuard {
    IERC721 public immutable nft;
    uint256 public immutable nftId;
    uint256 public immutable startingBid;

    address payable public immutable seller;

    uint32 public endAt;
    bool public started;
    bool public ended;

    address public highestBidder;
    uint256 public highestBid;

    mapping(address => uint256) public bids;

    event Start();
    event Bid(address indexed sender, uint256 amount);
    event Withdraw(address indexed bidder, uint256 amount);
    event End(address indexed winner, uint256 amount);
    event AuctionReset();
    event NFTWithdrawnByAdmin();

    constructor(
        address _nft,
        uint256 _nftId,
        uint256 _startingBid
    ) Ownable(msg.sender) {
        nft = IERC721(_nft);
        nftId = _nftId;
        seller = payable(msg.sender);
        startingBid = _startingBid;
        highestBid = _startingBid;
    }

    function start() external onlyOwner {
        if (started) revert AlreadyStarted();

        started = true;
        endAt = uint32(block.timestamp + 60); // 60-second auction
        nft.transferFrom(seller, address(this), nftId);

        emit Start();
    }

    function bid() external payable nonReentrant {
        if (!started) revert NotStarted();
        if (block.timestamp >= endAt) revert AlreadyEnded();
        if (msg.value <= highestBid) revert BidTooLow();

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        uint256 bal = bids[msg.sender];
        if (bal == 0) revert NoFundsToWithdraw();

        bids[msg.sender] = 0;
        payable(msg.sender).transfer(bal);

        emit Withdraw(msg.sender, bal);
    }

    function end() external nonReentrant {
        if (!started) revert NotStarted();
        if (ended) revert AlreadyEnded();
        if (block.timestamp < endAt) revert NotEnded();

        ended = true;

        if (highestBidder != address(0)) {
            nft.transferFrom(address(this), highestBidder, nftId);
            seller.transfer(highestBid);
        } else {
            nft.transferFrom(address(this), seller, nftId);
        }

        emit End(highestBidder, highestBid);
    }

    // Admin-only: Withdraw NFT in case auction gets stuck
    function emergencyWithdrawNFT() external onlyOwner {
        require(!started || ended, "Auction still active");
        nft.transferFrom(address(this), owner(), nftId);
        emit NFTWithdrawnByAdmin();
    }

    // Admin-only: Reset auction (only if not started or already ended)
    function resetAuction(uint256 _newStartingBid) external onlyOwner {
        require(!started || ended, "Cannot reset active auction");

        highestBid = _newStartingBid;
        started = false;
        ended = false;
        highestBidder = address(0);
        endAt = 0;

        emit AuctionReset();
    }
}

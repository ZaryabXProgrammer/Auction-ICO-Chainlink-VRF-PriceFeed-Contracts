// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol"; // Using Chainlink's official repo


contract BasicPresale is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;

    // Events
    event TokensPurchased(address indexed buyer, uint256 amountUSD, uint256 tokensAllocated);
    event TokensClaimed(address indexed claimer, uint256 amount);
    event Refunded(address indexed user, uint256 amount);
    event PresaleStarted();
    event PresaleEnded();
    event FundsWithdrawn(address token, uint256 amount);
    event ETHWithdrawn(uint256 amount);

    // Presale settings
    IERC20Metadata public token; // The token being sold
    address payable public treasuryWallet;
    AggregatorV3Interface public ethPriceFeed;

    uint256 public usdSoftCap = 1_000_000 * 1e6; // 1M USDT (6 decimals)
    uint256 public minContribution = 50 * 1e6; // $50
    uint256 public maxContribution = 100_000 * 1e6; // $100K
    uint256 public tokenPriceUsd; // Price per token in USD with 18 decimals

    uint256 public totalUsdRaised;
    uint256 public vestingStartTime;
    uint256 public constant vestingDuration = 270 days;
    bool public presaleActive;
    bool public presaleFinished;

    mapping(address => uint256) public usdInvested;
    mapping(address => uint256) public tokensAllocated;
    mapping(address => uint256) public tokensClaimed;

    // Accepted stablecoins
    mapping(address => bool) public acceptedStablecoins;

    constructor(
        address _token,
        address payable _treasuryWallet,
        uint256 _tokenPriceUsd,
        address _ethPriceFeed,
        address[] memory _stablecoins
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(_ethPriceFeed != address(0), "Invalid price feed");

        token = IERC20Metadata(_token);
        treasuryWallet = _treasuryWallet;
        ethPriceFeed = AggregatorV3Interface(_ethPriceFeed);
        tokenPriceUsd = _tokenPriceUsd;

        for (uint256 i = 0; i < _stablecoins.length; i++) {
            acceptedStablecoins[_stablecoins[i]] = true;
        }
    }

    // --- Presale Management ---

    function startPresale() external onlyOwner {
        require(!presaleActive, "Already active");
        presaleActive = true;
        emit PresaleStarted();
    }

    function endPresale() external onlyOwner {
        require(presaleActive, "Not active");
        presaleActive = false;
        presaleFinished = true;
        vestingStartTime = block.timestamp;
        emit PresaleEnded();
    }

    function pausePresale() external onlyOwner {
        _pause();
    }

    function unpausePresale() external onlyOwner {
        _unpause();
    }

    // --- Buy Functions ---

    function buyWithStablecoin(address stablecoin, uint256 amount) external whenNotPaused nonReentrant {
        require(presaleActive, "Presale not active");
        require(acceptedStablecoins[stablecoin], "Unsupported stablecoin");
        require(amount >= minContribution && amount <= maxContribution, "Invalid amount");

        IERC20Metadata(stablecoin).safeTransferFrom(msg.sender, address(this), amount);

        uint256 tokens = (amount * 1e18) / tokenPriceUsd;
        usdInvested[msg.sender] += amount;
        tokensAllocated[msg.sender] += tokens;
        totalUsdRaised += amount;

        emit TokensPurchased(msg.sender, amount, tokens);
    }

    function buyWithEth() external payable whenNotPaused nonReentrant {
        require(presaleActive, "Presale not active");
        uint256 ethUsdPrice = getLatestEthPrice();
        uint256 usdAmount = (msg.value * ethUsdPrice) / 1e18;
        require(usdAmount >= minContribution && usdAmount <= maxContribution, "Invalid amount");

        uint256 tokens = (usdAmount * 1e18) / tokenPriceUsd;
        usdInvested[msg.sender] += usdAmount;
        tokensAllocated[msg.sender] += tokens;
        totalUsdRaised += usdAmount;

        emit TokensPurchased(msg.sender, usdAmount, tokens);
    }

    // --- Claim Function ---

    function claimTokens() external nonReentrant {
        require(presaleFinished, "Presale not finished");
        require(totalUsdRaised >= usdSoftCap, "Soft cap not reached");

        uint256 claimable = getClaimableTokens(msg.sender);
        require(claimable > 0, "Nothing to claim");

        tokensClaimed[msg.sender] += claimable;
        token.safeTransfer(msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    function getClaimableTokens(address user) public view returns (uint256) {
        if (vestingStartTime == 0) return 0;

        uint256 totalAllocated = tokensAllocated[user];
        uint256 alreadyClaimed = tokensClaimed[user];

        if (totalAllocated == 0) return 0;

        uint256 elapsed = block.timestamp - vestingStartTime;
        uint256 vested;

        if (elapsed >= vestingDuration) {
            vested = totalAllocated;
        } else {
            vested = (totalAllocated * (10 + (elapsed * 90 / vestingDuration))) / 100;
        }

        if (vested <= alreadyClaimed) return 0;
        return vested - alreadyClaimed;
    }

    // --- Refund Function ---

    function refund(address stablecoin) external nonReentrant {
        require(!presaleFinished, "Presale ended");
        require(!presaleActive, "Presale still active");
        require(totalUsdRaised < usdSoftCap, "Soft cap reached");
        require(acceptedStablecoins[stablecoin], "Invalid stablecoin");

        uint256 invested = usdInvested[msg.sender];
        require(invested > 0, "No investment");

        usdInvested[msg.sender] = 0;
        tokensAllocated[msg.sender] = 0;

        IERC20Metadata(stablecoin).safeTransfer(msg.sender, invested);

        emit Refunded(msg.sender, invested);
    }

    // --- Admin Functions ---

    function withdrawFunds(address stablecoin, uint256 amount) external onlyOwner {
        IERC20Metadata(stablecoin).safeTransfer(treasuryWallet, amount);
        emit FundsWithdrawn(stablecoin, amount);
    }

    function withdrawEth(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        treasuryWallet.transfer(amount);
        emit ETHWithdrawn(amount);
    }

    function emergencyWithdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20Metadata(tokenAddress).safeTransfer(treasuryWallet, amount);
    }

    // --- Helpers ---

    function getLatestEthPrice() public view returns (uint256) {
        (, int256 answer,,,) = ethPriceFeed.latestRoundData();
        require(answer > 0, "Invalid price");
        return uint256(answer) * 1e10; // Chainlink ETH price feed returns 8 decimals
    }

    receive() external payable {
        revert("Use buyWithEth()");
    }
}

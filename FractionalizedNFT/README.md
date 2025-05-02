# 🧩 **FractionalizedNFT Smart Contract**

> A smart contract for fractional ownership of NFTs using ERC20 tokens.

---

## 🚀 **Features**

- **Fractionalizes** an ERC721 NFT into ERC20 tokens.
- Fully **ERC20-compliant** for transferability and liquidity.
- Owner can **list the NFT for sale**.
- Token holders can **redeem ETH** proportionally after NFT is sold.

---

## 📦 **Tech Stack**

- `Solidity ^0.8.28`
- `OpenZeppelin Contracts`
  - `ERC20`
  - `ERC20Permit`
  - `ERC721`
  - `Ownable`
  - `ERC721Holder`

---

## 📄 **Function Overview**

### `initialize(address _collection, uint256 _tokenId, uint256 _amount)`
- Initializes the contract with an NFT and mints ERC20 tokens.
- Transfers NFT from caller to contract.
- **Only callable by owner.**

### `putForSale(uint256 price)`
- Lists the NFT for sale at a given price (in Wei).
- **Only callable by owner.**

### `purchase() payable`
- Transfers NFT to buyer if enough ETH is sent.
- Enables redemption for token holders.

### `redeem(uint256 _amount)`
- Burns user's tokens.
- Sends proportional ETH share based on total token supply.

---

## 🔐 **Access Control**

- `initialize()` and `putForSale()` are **restricted to owner**.
- `purchase()` and `redeem()` are **public** and available post-sale.

---

## 🧪 **Example Workflow**

1. 🛠 Owner calls `initialize()` to lock NFT and mint ERC20 tokens.
2. 🔁 Tokens can be transferred between users.
3. 💸 Owner lists NFT with `putForSale(10 ether)`.
4. 🧍 Buyer calls `purchase()` sending 10 ETH.
5. 🪙 Token holders call `redeem()` to claim ETH proportional to their token holdings.

---

## ⚠️ **Notes**

- NFT must be `approved` before calling `initialize()`.
- Redemption is only possible **after NFT is sold**.
- ETH is distributed based on `(_amount / totalSupply) * totalBalance`.

---

## 📃 **License**

`MIT License`

---

🖤 Optimized for dark mode readability.

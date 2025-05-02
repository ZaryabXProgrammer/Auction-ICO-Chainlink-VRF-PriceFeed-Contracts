🧩 FractionalizedNFT Smart Contract
This smart contract enables fractional ownership of an ERC721 NFT by converting it into ERC20 tokens, allowing multiple parties to own shares of a single NFT. Once the NFT is sold, token holders can redeem their share of the sale proceeds.

🚀 Features
Fractionalization: Converts a single NFT into divisible ERC20 tokens.

ERC20 Standard: Allows tokens to be transferred, traded, or held like any fungible token.

NFT Sale: The owner can list the NFT for sale at a specified price.

Proceeds Redemption: After the NFT is sold, token holders can redeem their tokens for a proportional share of the ETH received.

📦 Technologies Used
Solidity ^0.8.28

OpenZeppelin Contracts (ERC20, ERC721, Permit, Ownable, ERC721Holder)

📄 Contract Functions
initialize(address _collection, uint256 _tokenId, uint256 _amount)
Initializes the contract with the NFT and mints ERC20 tokens.

Only callable once by the contract owner.

Transfers the specified NFT to the contract.

putForSale(uint256 price)
Owner lists the NFT for sale at the given price.

purchase() payable
Allows a buyer to purchase the NFT by sending ETH.

Transfers the NFT to the buyer.

Enables redemption of proceeds by token holders.

redeem(uint256 _amount)
Token holders can redeem their tokens for a proportional share of the ETH collected from the NFT sale.

Tokens are burned upon redemption.

🔐 Access Control
Only the owner can initialize and list the NFT for sale.

Anyone can purchase or redeem according to function requirements.

📌 Notes
NFT must be approved for transfer before calling initialize.

Redemptions are only available after the NFT has been sold.

The total ETH is divided among token holders proportionally to their holdings.

🧪 Example Use Case
Owner calls initialize() to fractionalize an NFT into 1000 tokens.

Users trade tokens freely as ERC20.

Owner lists the NFT for 10 ETH via putForSale().

Buyer purchases the NFT with purchase().

Token holders call redeem() to claim their share of 10 ETH based on the number of tokens they hold.

📃 License
This project is licensed under the MIT License.

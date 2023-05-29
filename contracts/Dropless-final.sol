// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @custom:security-contact mvinathan@gmail.com
contract Dropless is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, UUPSUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    struct PriceData {
        uint256 price;
        uint256 timestamp;
    }

    PriceData public priceData;

    uint256 public timeLapse;
    uint256 public priceDrop;
    uint256 public pauseDuration;

    uint256 private lastPauseEndTime;

    // Discounts for holding specific tokens
    mapping(address => uint256) public tokenDiscounts;

    // Discounts for holding specific NFTs
    mapping(address => mapping(uint256 => uint256)) public nftDiscounts;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialSupply) initializer public {
        __ERC20_init("Dropless", "DROP");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("Dropless");
        __UUPSUpgradeable_init();

        _mint(msg.sender, initialSupply);
        timeLapse = 1 hours;
        priceDrop = 10;
        pauseDuration = 12 hours;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
    }

    function setTokenDiscount(address token, uint256 discount) external onlyRole(OWNER_ROLE) {
        tokenDiscounts[token] = discount;
    }

    function setNftDiscount(address nft, uint256 tokenId, uint256 discount) external onlyRole(OWNER_ROLE) {
        nftDiscounts[nft][tokenId] = discount;
    }

    // Other functions...

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (paused()) {
            require(to != address(this), "Dropless: Cannot send to the contract while paused");

            uint256 fee = (amount * feePercentage) / 100; // calculates fee as a percentage of the transfer amount

            // Check if the sender has any tokens that give discounts
            for (address
            // ...
            // Check if the sender has any tokens that give discounts
            for (address token in tokenAddresses) {
                if (IERC20(token).balanceOf(from) > 0) {
                    uint256 discount = tokenDiscounts[token];
                    fee = (fee * (100 - discount)) / 100;
                    break;
                }
            }

            // Check if the sender has any NFTs that give discounts
            for (address nft in nftAddresses) {
                IERC721 nftContract = IERC721(nft);
                uint256 balance = nftContract.balanceOf(from);
                for (uint256 i = 0; i < balance; i++) {
                    uint256 tokenId = nftContract.tokenOfOwnerByIndex(from, i);
                    if (nftDiscounts[nft][tokenId] > 0) {
                        uint256 discount = nftDiscounts[nft][tokenId];
                        fee = (fee * (100 - discount)) / 100;
                        break;
                    }
                }
            }

            // Transfer the fee to the owner and subtract it from the transfer amount
            _transfer(from, getOwner(), fee);
            amount -= fee;
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
    {}

    function getOwner() public view returns (address) {
        return getRoleMember(OWNER_ROLE, 0);
    }
}

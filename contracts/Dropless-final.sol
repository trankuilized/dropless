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

    uint256[] public pauseDurations;  // Durations for each price decrease range
    uint256[] public priceDecreaseRanges;  // Price decrease ranges (e.g., [10, 20, 30] for ranges of up to 10%, 20%, 30%)

    uint256 private lastPauseEndTime;

    // Discounts for holding specific tokens
    mapping(address => uint256) public tokenDiscounts;

    // Discounts for holding specific NFTs
    mapping(address => mapping(uint256 => uint256)) public nftDiscounts;

    address public feeReceiver;  // The address that receives the fees
    uint256 public feePercentage;  // The fee percentage (0 - 100)

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

    function updatePriceData(uint256 _price, uint256 _timestamp) external {
        uint256 priceDecrease = (priceData.price - _price) * 100 / priceData.price;
        if (priceData.price > 0 && priceDecrease > priceDrop) {
            if (_timestamp - priceData.timestamp <= timeLapse && block.timestamp >= lastPauseEndTime) {
                _pause();

                // Determine pause duration based on price drop
                for (uint256 i = 0; i < priceDecreaseRanges.length; i++) {
                    if (priceDecrease <= priceDecreaseRanges[i]) {
                        pauseDuration = pauseDurations[i];
                        break;
                    }
                }

                lastPauseEndTime = block.timestamp + pauseDuration;
            }
        }
        priceData.price = _price;
        priceData.timestamp = _timestamp;
    }

    function setPauseDurations(uint256[] calldata newPauseDurations) external onlyRole(OWNER_ROLE) {
        pauseDurations = newPauseDurations;
    }

    function setPriceDecreaseRanges(uint256[] calldata newPriceDecreaseRanges) external onlyRole(OWNER_ROLE) {
        priceDecreaseRanges = newPriceDecreaseRanges;
    }

    function setFeeReceiver(address _feeReceiver) external onlyRole(OWNER_ROLE) {
        feeReceiver = _feeReceiver;
    }

    function setFeePercentage(uint256 _feePercentage) external onlyRole(OWNER_ROLE) {
        require(_feePercentage <= 100, "Dropless: feePercentage cannot be more than 100");
        feePercentage = _feePercentage;
    }

    function forceUnpause() external onlyRole(OWNER_ROLE) {
        _unpause();
        lastPauseEndTime = block.timestamp;
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (paused()) {
            require(to != address(this), "Dropless: Cannot send to the contract while paused");

            uint256 fee = (amount * feePercentage) / 100; // calculates fee as a percentage of the transfer amount

            // apply fees only on transfers not involving the contract address (prevents blocking token purchases)
            if (from != address(this) && to != address(this)) {
                require(amount - fee <= balanceOf(from), "Dropless: Transfer amount + fee exceeds balance");
                _transfer(from, feeReceiver, fee); // transfer the fee
            }

            super._beforeTokenTransfer(from, to, amount - fee); // transfer the remaining amount
        } else {
            super._beforeTokenTransfer(from, to, amount);
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
    {}

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function getOwner() public view returns (address) {
        return getRoleMember(OWNER_ROLE, 0);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20PermitUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract Dropless is Context, ERC20, Pausable, Ownable, ERC20Burnable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
    }

    PriceData public priceData;

    uint256 public timeLapse;
    uint256 public priceDrop;
    uint256 public pauseDuration;

    uint256 private lastPauseEndTime;

    constructor(uint256 initialSupply) ERC20("Dropless", "DRP") {
        _mint(_msgSender(), initialSupply);
        timeLapse = 1 hours;
        priceDrop = 10;
        pauseDuration = 12 hours;
    }

    function updatePriceData(uint256 _price, uint256 _timestamp) external {
        if (priceData.price > 0 && (priceData.price * (100 - priceDrop)) / 100 >= _price) {
if (_timestamp - priceData.timestamp <= timeLapse && block.timestamp >= lastPauseEndTime) {
_pause();
lastPauseEndTime = block.timestamp + pauseDuration;
}
}
priceData.price = _price;
priceData.timestamp = _timestamp;
}
function setTimeLapse(uint256 _timeLapse) external onlyOwner {
    timeLapse = _timeLapse;
}

function setPriceDrop(uint256 _priceDrop) external onlyOwner {
    priceDrop = _priceDrop;
}

function setPauseDuration(uint256 _pauseDuration) external onlyOwner {
    pauseDuration = _pauseDuration;
}

function forceUnpause() external onlyOwner {
    _unpause();
    lastPauseEndTime = block.timestamp;
}

function mint(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
}

function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
) internal virtual override {
    require(!paused() || block.timestamp < lastPauseEndTime, "Dropless: token transfer while paused");
    super._beforeTokenTransfer(from, to, amount);
}

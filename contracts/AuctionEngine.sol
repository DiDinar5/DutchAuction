// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract AucEngine {
    address public owner;
    uint256 constant DURATION = 2 days; 
    uint256 constant FEE = 10; // 10%

    struct Auction {
        address payable seller;
        uint256 startingPrice;
        uint256 finalPrice;
        uint256 startAt;
        uint256 endsAt;
        uint256 discountRate;
        string item;
        bool stopped;
    }

    Auction[] public auctions;

    event AuctionCreated(uint256 index, string itemName, uint256 startingPrice, uint256 duration);
    event AuctionEnded(uint256 index, uint256 finalPrice, address winner);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
    }

    function createAuction(
        uint256 _startingPrice,
        uint256 _discountRate,
        string memory _item,
        uint256 _duration
    ) external {
        uint256 duration = _duration == 0 ? DURATION : _duration;
        require(_startingPrice >= _discountRate * duration, "Starting price too low");

        Auction memory newAuction = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: 0,
            discountRate: _discountRate,
            startAt: block.timestamp,
            endsAt: block.timestamp + duration,
            item: _item,
            stopped: false
        });

        auctions.push(newAuction);
        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    function getPriceFor(uint256 index) public view returns (uint256) {
        Auction storage cAuction = auctions[index];
        require(!cAuction.stopped, "Auction has been stopped");
        uint256 elapsed = block.timestamp - cAuction.startAt;
        uint256 discount = cAuction.discountRate * elapsed;
        return cAuction.startingPrice > discount ? cAuction.startingPrice - discount : 0;
    }

    function buy(uint256 index) external payable {
        Auction storage cAuction = auctions[index];
        require(!cAuction.stopped, "Auction has been stopped");
        require(block.timestamp < cAuction.endsAt, "Auction has ended");

        uint256 cPrice = getPriceFor(index);
        require(msg.value >= cPrice, "Insufficient funds");

        cAuction.stopped = true;
        cAuction.finalPrice = cPrice;

        uint256 refund = msg.value - cPrice;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        uint256 sellerAmount = cPrice - (cPrice * FEE) / 100;
        cAuction.seller.transfer(sellerAmount);

        emit AuctionEnded(index, cPrice, msg.sender);
    }
}

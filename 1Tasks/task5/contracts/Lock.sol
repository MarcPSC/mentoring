pragma solidity ^0.8.0;

import "../node_modules/hardhat/console.sol";

contract Auction {

    enum Status { Successfull, Failed, Ongoing }
    
    // Struct to store auction details
    struct AuctionDetails {
        address creator;
        address lastBidder;
        uint256 startingTime;
        uint256 endTime;
        uint256 startingPrice;
        uint256 currentPrice;
        Status status;
        mapping (address => uint256) bids;
    }
    
    // Events
    event AuctionCreated(uint256 auctionId, address creator, uint256 startingPrice, uint256 startingTime, uint256 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionEnded(uint256 auctionId, address winner, uint256 amount);
    
    // Variables
    uint256 public auctionId;
    mapping (uint256 => AuctionDetails) public auctions;
    
    // Create new auction
    function createAuction(uint256 startingPrice) public {
        auctionId++;
        AuctionDetails storage auction = auctions[auctionId]; 
        auction.creator = msg.sender;
        auction.startingTime = block.timestamp;
        auction.endTime = block.timestamp + 1800;
        auction.startingPrice = startingPrice;
        auction.currentPrice = startingPrice;
        auction.status = Status.Ongoing;
    }
    
    // Place a bid
    function placeBid(uint256 _auctionId) public payable {
        require(block.timestamp < auctions[_auctionId].endTime, "Auction has ended");
        require(msg.value > auctions[_auctionId].currentPrice, "Bid must be higher than current price");
        auctions[_auctionId].bids[msg.sender] = msg.value;
        auctions[_auctionId].currentPrice = msg.value;
        auctions[_auctionId].lastBidder = msg.sender;
        auctions[_auctionId].status = Status.Ongoing;
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }
    
    // End auction
    function endAuction(uint256 _auctionId) public {
        require(block.timestamp >= auctions[_auctionId].endTime, "Auction has not ended yet");
        require(auctions[_auctionId].status == Status.Ongoing, "Auction already finished");
        if(auctions[_auctionId].lastBidder==address(0)) {
            auctions[_auctionId].status = Status.Failed;
            revert("Auction failed");
        }
        auctions[_auctionId].status = Status.Successfull;
        uint256 highestBid = auctions[_auctionId].currentPrice;
        //payable(auctions[_auctionId].creator).transfer(highestBid);
        (bool sent, bytes memory data) = payable(auctions[_auctionId].creator).call{value: highestBid}("");
        require(sent, "Failed to send Ether");
    }
    
    // Withdraw bid
    function withdrawBid(uint256 _auctionId) public {
        require(auctions[_auctionId].bids[msg.sender] > 0, "You have not bid in this auction");
        require(msg.sender != auctions[_auctionId].lastBidder || (msg.sender == auctions[_auctionId].lastBidder && Status.Failed == auctions[_auctionId].status), "The winner of an auction cannot withdraw its bid");
        uint256 amount = auctions[_auctionId].bids[msg.sender];
        auctions[_auctionId].bids[msg.sender] = 0;
        //payable(msg.sender).transfer(amount);
        (bool sent, bytes memory data) = payable(auctions[_auctionId].creator).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
    
    // Get auction details
    function getAuctionDetails(uint256 _auctionId) public view returns (address, uint256, uint256, Status, uint256, uint256) {
        return (auctions[_auctionId].creator, auctions[_auctionId].startingTime, auctions[_auctionId].endTime, auctions[_auctionId].status, auctions[_auctionId].startingPrice, auctions[_auctionId].currentPrice);
    }

    /* function getStatus(uint256 id) public view returns (Status){
        if(id == 0)return Status.Failed; //1
        if(id == 1)return Status.Successfull; //0
        return Status.Ongoing; //2
    } */
}





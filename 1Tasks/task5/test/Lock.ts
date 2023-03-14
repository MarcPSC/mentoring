const { expect } = require("chai");
const { ethers } = require("hardhat");
import { Contract, Signer } from "ethers";

describe("Auction", function () {
  let auction:Contract;
  let owner:Signer;
  let bidder1:Signer;
  let bidder2:Signer;
  let startingPrice: any;
  let ownerStartBalance: any;
  let auctionId: number;

  beforeEach(async function () {
    [owner, bidder1, bidder2] = await ethers.getSigners();

    const Auction = await ethers.getContractFactory("Auction");
    auction = await Auction.deploy();
    await auction.deployed();

    startingPrice = ethers.utils.parseEther("1");
    await auction.connect(owner).createAuction(startingPrice);
    ownerStartBalance = await ethers.provider.getBalance(owner.getAddress())
    auctionId = 1;
  });


  describe("createAuction", function() {
    it("Should create a new auction", async function () {
      const startingPrice = ethers.utils.parseEther("1");

      const tx = await auction.connect(owner).createAuction(startingPrice);

      await tx.wait();

      const [creatorAddress, startingTime, endTime, status, _startingPrice, currentPrice] = await auction.getAuctionDetails(1);

      expect(creatorAddress).to.equal(await owner.getAddress());
      expect(startingPrice).to.equal(_startingPrice);
      expect(currentPrice).to.equal(startingPrice);
      expect(endTime).to.equal(Number(startingTime) + 1800)
      expect(status).to.equal(2); 
    });
  });

  describe("placeBid", function () {
    it("should allow a higher bid than the current price to be placed", async function () {
      const initialBalance = await bidder1.getBalance();
      const bidAmount = ethers.utils.parseEther("1.5");
      await auction.connect(bidder1).placeBid(1, { value: bidAmount });

      const auctionDetails = await auction.getAuctionDetails(1);
      expect(auctionDetails[5]).to.equal(bidAmount);
      expect(auctionDetails[3]).to.equal(2);
      expect(auctionDetails[1]).to.be.closeTo(Math.floor(Date.now() / 1000), 5);
      expect(auctionDetails[2]).to.be.closeTo(Math.floor(Date.now() / 1000) + 1800, 5);
    });

    it("should not allow a lower or equal bid than the current price to be placed", async function () {
      const startingPrice = ethers.utils.parseEther("1");
      await auction.createAuction(startingPrice);

      const lowerBid = ethers.utils.parseEther("0.5");
      await expect(auction.connect(bidder1).placeBid(1, { value: lowerBid })).to.be.revertedWith("Bid must be higher than current price");

      const equalBid = ethers.utils.parseEther("1");
      await expect(auction.connect(bidder1).placeBid(1, { value: equalBid })).to.be.revertedWith("Bid must be higher than current price");
    });
  
    it("should not allow a bid after auction has ended", async function() {
      const startingPrice = ethers.utils.parseEther("1");
      await auction.createAuction(startingPrice);
  
      await ethers.provider.send("evm_increaseTime", [1801]); // increase time by 1801 seconds to simulate end of auction
  
      await expect(auction.connect(bidder1).placeBid(1, { value: ethers.utils.parseEther("2") })).to.be.revertedWith("Auction has ended");
    });
  });

  describe("endAuction", function() {
    it("should transfer the highest bid to the creator when the auction ends successfully", async function () {
      const bid1 = ethers.utils.parseEther("2");
      const bid2 = ethers.utils.parseEther("3");
      await auction.connect(bidder1).placeBid(auctionId, { value: bid1 });
      await auction.connect(bidder2).placeBid(auctionId, { value: bid2 });
  
      await ethers.provider.send("evm_increaseTime", [1800]);
      const tx = await auction.connect(owner).endAuction(auctionId);
      const receipt = await tx.wait();
      const gasUsed = receipt.cumulativeGasUsed * receipt.effectiveGasPrice;
  
      const finalBalance = await ethers.provider.getBalance(owner.getAddress());
      expect(ownerStartBalance.add(bid2).sub(gasUsed)).to.equal(finalBalance);
    });
  
    it("should revert if the auction has not ended yet", async function () {
      await expect(
        auction.connect(owner).endAuction(auctionId)
      ).to.be.revertedWith("Auction has not ended yet");
    });
  
    it("should revert if the auction has already ended", async function () {
      const bid = ethers.utils.parseEther("2");
      await auction.connect(bidder1).placeBid(auctionId, { value: bid });
      await ethers.provider.send("evm_increaseTime", [1800]); 
      await auction.connect(owner).endAuction(auctionId);
  
      await expect(
        auction.connect(owner).endAuction(auctionId)
      ).to.be.revertedWith("Auction already finished");
    });
  
    it("should revert the auction as failed if there was no bid", async function () {
      await ethers.provider.send("evm_increaseTime", [1800]); 
  
      await expect(
        auction.connect(owner).endAuction(auctionId)
      ).to.be.revertedWith("Auction failed");
    });
  });

  describe("withdrawBid", function() {
    it("Bidder can withdraw bid before auction ends if they are not the highest bidder", async function () {
      await auction.connect(bidder1).placeBid(1, { value: ethers.utils.parseEther("1.1") });
      await auction.connect(bidder2).placeBid(1, { value: ethers.utils.parseEther("1.2") });
  
      const withdrawTx = await auction.connect(bidder1).withdrawBid(1);
  
      expect(withdrawTx).to.emit(auction, "BidWithdrawn").withArgs(1, bidder1.getAddress(), ethers.utils.parseEther("1.1"));
    });
  
    it("Non-bidder cannot withdraw bid", async function () {
      await auction.connect(bidder1).placeBid(1, { value: ethers.utils.parseEther("1.1") });
  
      await expect(auction.connect(bidder2).withdrawBid(1)).to.be.revertedWith("You have not bid in this auction");
    });
  
    it("Winner cannot withdraw bid", async function () {
      await auction.connect(bidder1).placeBid(1, { value: ethers.utils.parseEther("1.1") });
  
      await ethers.provider.send("evm_increaseTime", [1801]);
  
      await auction.endAuction(1);
  
      await expect(auction.connect(bidder1).withdrawBid(1)).to.be.revertedWith("The winner of an auction cannot withdraw its bid");
    });
  });

  describe("getAuctionDetails", function() {
    it("should return correct auction details", async function() {
      await auction.createAuction(startingPrice);
      const auctionId = 1;
      const [creatorAddress, startingTime, endTime, status, _startingPrice, currentPrice] = await auction.getAuctionDetails(auctionId);

      expect(creatorAddress).to.equal(await owner.getAddress());
      expect(startingPrice).to.equal(_startingPrice);
      expect(currentPrice).to.equal(startingPrice);
      expect(endTime).to.equal(Number(startingTime) + 1800)
      expect(status).to.equal(2); 
  
      await auction.connect(bidder1).placeBid(1, { value: ethers.utils.parseEther("1.1") });
      await ethers.provider.send("evm_increaseTime", [1801]);
      await auction.endAuction(auctionId);
  
      const [creator2, startingTime2, endTime2, status2, initialPrice2, currentPrice2] = await auction.getAuctionDetails(auctionId);
  
      expect(creator2).to.equal(await owner.getAddress());
      expect(startingPrice).to.equal(_startingPrice);
      expect(currentPrice).to.equal(startingPrice);
      expect(endTime).to.equal(Number(startingTime) + 1800)
      expect(status2).to.equal(0);
    });
  });
});
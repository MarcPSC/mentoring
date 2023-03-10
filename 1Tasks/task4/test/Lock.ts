import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("Lock", function () {
  
  let contract: Contract;
  let owner: Signer;
  let addr1: Signer;
  let addr2: Signer;
  let addr3: Signer;

  // Deploy a new instance of the contract before each test case
  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const Lock = await ethers.getContractFactory("Lock");
    contract = await Lock.deploy();
    await contract.deployed();
  });

  describe("Vote", function () {
    // Test that users can vote for different options
    it("Allows users to vote for different options", async function () {
      await contract.connect(addr1).vote(0, {value: ethers.utils.parseEther("1")});
      await contract.connect(addr2).vote(1, {value: ethers.utils.parseEther("0.5")});

      expect(await contract.optionVotes(0)).to.equal(1);
      expect(await contract.optionVotes(1)).to.equal(0);
    });

    it("Should keep the correct wining option", async function () {
      await contract.connect(addr1).vote(0, {value: ethers.utils.parseEther("1")});
      await contract.connect(addr2).vote(1, {value: ethers.utils.parseEther("0.5")});

      expect(await contract.winningOption()).to.equal(0);
    });

    // Test that users cannot change their vote after casting it
    it("Prevents users from changing their vote", async function () {
      await contract.connect(addr1).vote(0, {value: ethers.utils.parseEther("1")});

      await expect(contract.connect(addr1).vote(1, {value: ethers.utils.parseEther("1")})).to.be.revertedWith("Cannot change vote.");
    });

    it("should not allow votes after the contract period has ended", async function () {
      await ethers.provider.send("evm_increaseTime", [172800]);

      await expect(contract.connect(addr1).vote(1, {value: ethers.utils.parseEther("1")})).to.be.revertedWith("Voting period has ended.");
    });

    it("should not allow votes with an amount of 0", async function () {
      await expect(contract.connect(addr1).vote(0, {value: ethers.utils.parseEther("0")}))
        .to.be.revertedWith("Amount cannot be zero.");
    });
  });

  describe("Distribute", function () {

    it("should not allow to distribute the eth before the contract period has ended", async function () {
      await expect(contract.connect(addr2).distributeBonus()).to.be.revertedWith("Voting period has not ended.");
    });

    it("Distributes bonus to participants who voted for the winning option", async function () {
      await contract.connect(addr1).vote(0, { value: ethers.utils.parseEther("2") });
      await contract.connect(addr3).vote(0, { value: ethers.utils.parseEther("3") });
      await contract.connect(addr1).vote(0, { value: ethers.utils.parseEther("7.5") });
      await contract.connect(addr2).vote(1, { value: ethers.utils.parseEther("2.5") });


      const initialAddr1Balance = await ethers.provider.getBalance(addr1.getAddress());
      const initialAddr2Balance = await ethers.provider.getBalance(addr2.getAddress());
      const initialAddr3Balance = await ethers.provider.getBalance(addr3.getAddress());

      const winningOption = await contract.winningOption();
      await ethers.provider.send("evm_increaseTime", [172800]);
      const tx1 = await contract.connect(addr1).distributeBonus();
      const receipt1 = await tx1.wait();
      const gasUsed1 = tx1.gasPrice?.mul(receipt1.gasUsed);
      //console.log(receipt1);
      
      const tx2 = await contract.connect(addr2).distributeBonus();
      const receipt2 = await tx2.wait();
      const gasUsed2 = tx2.gasPrice?.mul(receipt2.gasUsed);
      //console.log(receipt2);
      
      const tx3 = await contract.connect(addr3).distributeBonus();
      const receipt3 = await tx3.wait();
      const gasUsed3 = tx3.gasPrice?.mul(receipt3.gasUsed);
      //console.log(receipt2);

      const addr1Balance = await ethers.provider.getBalance(addr1.getAddress());
      const addr2Balance = await ethers.provider.getBalance(addr2.getAddress());
      const addr3Balance = await ethers.provider.getBalance(addr3.getAddress());
      /* console.log(initialAddr1Balance.sub(gasUsed1));
      console.log(initialAddr1Balance.add(ethers.utils.parseEther("2.5")).sub(gasUsed1));
      console.log(addr1Balance);  */

      expect(addr1Balance).to.equal(initialAddr1Balance.add(ethers.utils.parseEther("11.25")).sub(gasUsed1));
      expect(addr2Balance).to.equal(initialAddr2Balance.add(ethers.utils.parseEther("0")).sub(gasUsed2));
      expect(addr3Balance).to.equal(initialAddr3Balance.add(ethers.utils.parseEther("3.75")).sub(gasUsed3));
    });
  });
});
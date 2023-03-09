import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { Provider } from "@ethersproject/abstract-provider";

describe("Test", function () {
  let contract: Contract;
  let owner: Signer;
  let otherAccount: Signer;
  let otherAccount2: Signer;
  
  beforeEach(async function () {
      [owner, otherAccount, otherAccount2] = await ethers.getSigners();
      const Lock = await ethers.getContractFactory("Lock");
      contract = await Lock.connect(owner).deploy();
      await contract.deployed();
  });

  describe("contribute()", function () {
    it("should allow a user to contribute to the contract", async function () {
        await contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")});
        expect(await contract.contributions(owner.getAddress())).to.equal(ethers.utils.parseEther("0.1"));
        expect(await contract.totalAmount()).to.equal(ethers.utils.parseEther("0.1"));
    });
    
    it("should not allow a user to contribute twice", async function () {
        await contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")});
        await expect(contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")})).to.be.revertedWith("User has already participated");
    });
    
    it("should allow a user to contribute only if unlocked", async function () {
        await contract.connect(owner).lock();
        await expect(contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")})).to.be.revertedWith("Contract is locked");
        await contract.connect(owner).unlock();
        await contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")});
        expect(await contract.contributions(owner.getAddress())).to.equal(ethers.utils.parseEther("0.1"));
        expect(await contract.totalAmount()).to.equal(ethers.utils.parseEther("0.1"));
    });
    
    it("should not allow a user to contribute below the minimum amount", async function () {
        await expect(contract.connect(owner).contribute({value: ethers.utils.parseEther("0.04")})).to.be.revertedWith("Invalid contribution amount");
    });
    
    it("should not allow a user to contribute above the maximum amount", async function () {
        await expect(contract.connect(owner).contribute({value: ethers.utils.parseEther("0.21")})).to.be.revertedWith("Invalid contribution amount");
    });
    
    it("should not allow contributions after the contract period has ended", async function () {
        await ethers.provider.send("evm_increaseTime", [172800]); 
        await expect(contract.connect(owner).contribute({value: ethers.utils.parseEther("0.1")})).to.be.revertedWith("Crowdfunding has ended");
    });
  });

  describe("lock()", function () {
    it("should allow the creator to lock the contract", async function () {
        await contract.lock();
        expect(await contract.isLocked()).to.equal(true);
    });
    
    it("should not allow a non-creator to lock the contract", async function () {
        await expect(contract.connect(otherAccount).lock()).to.be.revertedWith("Only the creator can perform this action");
    });
});

describe("unlock()", function () {
    it("should allow the creator to unlock the contract", async function () {
        await contract.lock();
        await contract.unlock();
        expect(await contract.isLocked()).to.equal(false);
    });
    
    it("should not allow a non-creator to unlock the contract", async function () {
        await contract.lock();
        await expect(contract.connect(otherAccount).unlock()).to.be.revertedWith("Only the creator can perform this action");
    });
});
});

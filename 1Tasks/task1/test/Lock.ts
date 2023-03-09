import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { Contract, ContractFactory } from "ethers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Lock", function () {
  async function setValues() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Lock = await ethers.getContractFactory("Lock");

    const lock = await Lock.deploy();
    await lock.deployed();

    return { lock, owner, otherAccount };
  }

  describe("Test", function () {
    it("should have a default string value", async () => {
      const { lock, owner, otherAccount } = await loadFixture(setValues);
      const defaultValue: string = await lock.getString();
      expect(defaultValue).to.equal("First");
    });
  
    it("should allow the contract creator to update the string", async () => {
      const { lock, owner, otherAccount } = await loadFixture(setValues);
      const newString: string = "Second!";
      await lock.connect(owner).updateString(newString);
  
      const updatedValue: string = await lock.getString();
      expect(updatedValue).to.equal(newString);
    });
  
    it("should not allow non-creator to update the string", async () => {
      const { lock, owner, otherAccount } = await loadFixture(setValues);
      const newString: string = "Hello, World!";
  
      await expect(lock.connect(otherAccount).updateString(newString)).to.be.revertedWith(
        "Only contract creator can modify the string."
      );
    });
  });
});

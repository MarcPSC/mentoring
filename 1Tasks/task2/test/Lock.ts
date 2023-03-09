import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";

describe("Deposit", function () {
  async function setValues() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Lock = await ethers.getContractFactory("Lock");

    const contract = await Lock.deploy();
    await contract.deployed();

    return { contract, owner, otherAccount };
  };

  it("should allow users to deposit ETH", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const initialBalance = await ethers.provider.getBalance(contract.address);

    await contract.deposit({ value: depositAmount });

    const finalBalance = await ethers.provider.getBalance(contract.address);
    expect(finalBalance.sub(initialBalance)).to.equal(depositAmount);
  });

  it("should not allow users to deposit 0 ETH", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("0");

    await expect(contract.deposit({ value: depositAmount })).to.be.revertedWith(
      "Deposit amount must be greater than 0"
    );
  });
});

describe("Withdraw", function () {
  async function setValues() {
    const [owner, otherAccount] = await ethers.getSigners();
    //console.log(await owner.getBalance());

    const Lock = await ethers.getContractFactory("Lock");

    const contract = await Lock.deploy();
    await contract.deployed();

    return { contract, owner, otherAccount };
  };

  it("should allow users to withdraw ETH", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const withdrawalAmount = ethers.utils.parseEther("0.5");

    await contract.connect(owner).deposit({ value: depositAmount });
    const initialBalance = await ethers.provider.getBalance(contract.address);
    const initialUserBalance = await ethers.provider.getBalance(owner.address);
    //console.log(initialUserBalance);

    const tx = await contract.connect(owner).withdraw(withdrawalAmount);

    const receipt = await tx.wait();
    const gasUsed = tx.gasPrice?.mul(receipt.gasUsed);
    
    const finalBalance = await ethers.provider.getBalance(contract.address);
    const finalUserBalance = await ethers.provider.getBalance(owner.address);
    //console.log(finalUserBalance);

    expect(finalBalance).to.equal(initialBalance.sub(withdrawalAmount));
    expect(finalUserBalance).to.equal(initialUserBalance.add(withdrawalAmount).sub(gasUsed));
  });

  it("should not allow users to withdraw 0 ETH", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const withdrawalAmount = ethers.utils.parseEther("0");

    await expect(contract.withdraw(withdrawalAmount)).to.be.revertedWith(
      "Withdrawal amount must be greater than 0"
    );
  });

  it("should not allow users to withdraw ETH if not deposited first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const withdrawalAmount = ethers.utils.parseEther("0.5");

    await expect(contract.withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("should not allow users to withdraw ETH if not deposited enough first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const withdrawalAmount = ethers.utils.parseEther("1.5");

    await contract.connect(otherAccount).deposit({ value: depositAmount });

    await expect(contract.connect(otherAccount).withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("should not allow users to withdraw ETH if not deposited first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const withdrawalAmount = ethers.utils.parseEther("0.5");

    await contract.connect(otherAccount).deposit({ value: depositAmount });

    await expect(contract.connect(owner).withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });
});

describe("Withdraw all", function () {
  async function setValues() {
    const [owner, otherAccount] = await ethers.getSigners();

    const Lock = await ethers.getContractFactory("Lock");

    const contract = await Lock.deploy();
    await contract.deployed();

    return { contract, owner, otherAccount };
  };

  it("should allow owner to withdraw ETH", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");

    await contract.connect(otherAccount).deposit({ value: depositAmount });
    const initialUserBalance = await ethers.provider.getBalance(owner.address);
    //console.log(initialUserBalance);

    const tx = await contract.connect(owner).withdrawAll();

    const receipt = await tx.wait();
    const gasUsed = tx.gasPrice?.mul(receipt.gasUsed);

    const finalBalance = await ethers.provider.getBalance(contract.address);
    const finalUserBalance = await ethers.provider.getBalance(owner.address);
    //console.log(finalUserBalance);

    expect(finalBalance).to.equal(ethers.utils.parseEther("0"));
    expect(finalUserBalance).to.equal(initialUserBalance.add(depositAmount).sub(gasUsed));
  });

  it("should not allow owner to withdraw all if not any ETH deposited", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const withdrawalAmount = ethers.utils.parseEther("0");

    await expect(contract.withdrawAll()).to.be.revertedWith(
      "No balance to withdraw"
    );
  });

  it("should allow only owner to withdraw all", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);

    await expect(contract.connect(otherAccount).withdrawAll()).to.be.revertedWith(
      "Only the contract owner can perform this action"
    );
  });

  it("should not allow users to withdraw ETH if not deposited first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const withdrawalAmount = ethers.utils.parseEther("0.5");

    await expect(contract.withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("should not allow users to withdraw ETH if not deposited enough first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const withdrawalAmount = ethers.utils.parseEther("1.5");

    await contract.connect(otherAccount).deposit({ value: depositAmount });

    await expect(contract.connect(otherAccount).withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("should not allow users to withdraw ETH if not deposited first", async function () {
    const { contract, owner, otherAccount } = await loadFixture(setValues);
    const depositAmount = ethers.utils.parseEther("1");
    const withdrawalAmount = ethers.utils.parseEther("0.5");

    await contract.connect(otherAccount).deposit({ value: depositAmount });

    await expect(contract.connect(owner).withdraw(withdrawalAmount)).to.be.revertedWith(
      "Insufficient balance"
    );
  });
});

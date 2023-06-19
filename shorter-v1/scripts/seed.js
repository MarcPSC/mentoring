const hre = require("hardhat");
const { ethers } = require("hardhat");
// const { ethers, artifacts } from 'hardhat';

async function main() {
  await hre.run('compile');

  const [user1] = await ethers.getSigners();

  const DexCenter = await ethers.getContractFactory("DexCenter");
  const dexCenter = await DexCenter.deploy(user1.address);

  const ShorterBone = await ethers.getContractFactory("ShorterBone");
  const shorterBone = await ShorterBone.deploy(user1.address);

  const ShorterFactory = await ethers.getContractFactory("ShorterFactory");
  const shorterFactory = await ShorterFactory.deploy(user1.address);
  await shorterFactory.deployed();
  await dexCenter.deployed();
  await shorterBone.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

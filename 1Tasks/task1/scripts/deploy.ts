import { ethers } from "hardhat";

async function main() {
  //const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  //const unlockTime = currentTimestampInSeconds + 60;

  //const lockedAmount = ethers.utils.parseEther("0.001");

  const Lock = await ethers.getContractFactory("Lock");
  const lock = await Lock.deploy();

  await lock.deployed();

  const value = await lock.getString();

  console.log(
    `Lock with ${value}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

const hre = require("hardhat");

async function main() {
  const RewardContract = await hre.ethers.getContractFactory("Reward");
  const rewardContract = await RewardContract.deploy();
  await rewardContract.deployed();
  console.log(`Finished writing reward contract address: ${rewardContract.address}`);
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err);
    process.exit(1);
  });

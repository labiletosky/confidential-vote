const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying ConfidentialVote to Sepolia...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  const ConfidentialVote = await ethers.getContractFactory("ConfidentialVote");
  const contract = await ConfidentialVote.deploy();

  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("✅ ConfidentialVote deployed to:", address);
  console.log("View on Etherscan: https://sepolia.etherscan.io/address/" + address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

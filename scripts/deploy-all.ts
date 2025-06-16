import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("=== Deploying Prediction Market System ===");
  console.log("Deployer account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");
  console.log("");

  console.log("1. Deploying PredictionToken...");
  const PredictionToken = await ethers.getContractFactory("PredictionToken");
  const token = await PredictionToken.deploy(
    "Prediction Token",
    "pUSDC",
    100000000, // 100 million tokens
    deployer.address
  );
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  
  console.log("   ✅ PredictionToken deployed to:", tokenAddress);
  console.log("   📊 Total supply:", ethers.formatEther(await token.totalSupply()), "PRED");
  console.log("");

  // Deploy AIPredictionMarket
  console.log("2. Deploying AIPredictionMarket...");
  const aiOperator = deployer.address;
  
  const AIPredictionMarket = await ethers.getContractFactory("AIPredictionMarket");
  const predictionMarket = await AIPredictionMarket.deploy(
    aiOperator,
    tokenAddress
  );
  await predictionMarket.waitForDeployment();
  const marketAddress = await predictionMarket.getAddress();

  console.log("   ✅ AIPredictionMarket deployed to:", marketAddress);
  console.log("   🤖 AI Operator:", await predictionMarket.aiOperator());
  console.log("   🪙 Token:", await predictionMarket.token());
  console.log("");

  // Summary
  console.log("=== Deployment Summary ===");
  console.log("PredictionToken:", tokenAddress);
  console.log("AIPredictionMarket:", marketAddress);
  console.log("AI Operator:", aiOperator);
  console.log("");
  console.log("🎉 All contracts deployed successfully!");
  
  return {
    token: tokenAddress,
    market: marketAddress,
    aiOperator
  };
}

main()
  .then((result) => {
    console.log("Deployment result:", result);
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 
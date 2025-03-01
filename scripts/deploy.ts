import { ethers, network } from "hardhat";
import hre from "hardhat";

async function main() {
  try {
    // Ensure contracts are compiled
    console.log("Compiling contracts...");
    await hre.run("compile");

    // Deploy IERC20 interface if necessary
    // Note: IERC20 is usually only an interface and doesn't need deployment
    console.log("Checking IERC20 dependency...");

    // Deploy the PiggyFactory contract
    console.log("Deploying PiggyFactory...");
    const PiggyFactory = await ethers.getContractFactory("PiggyFactory");
    const factory = await PiggyFactory.deploy();

    // Wait for deployment to complete
    await factory.waitForDeployment();

    // Get the factory address
    const factoryAddress = await factory.getAddress();
    console.log(`PiggyFactory deployed to: ${factoryAddress}`);

    // Create a sample piggy bank
    console.log("\nCreating a sample piggy bank...");
    const [deployer] = await ethers.getSigners();

    // Parameters for the piggy bank
    const duration = 60 * 60 * 24 * 30; // 30 days in seconds
    const savingPurpose = "Vacation Fund";

    // Get predicted address before creation
    const predictedAddress = await factory.getPredictedAddress(
      deployer.address,
      duration,
      savingPurpose
    );
    console.log(`Predicted piggy bank address: ${predictedAddress}`);

    // Create the piggy bank
    const tx = await factory.createPiggy(duration, savingPurpose);
    const receipt = await tx.wait();

    // Parse logs to find the PiggyCreated event
    const factoryInterface = PiggyFactory.interface;
    const createdEvent = receipt?.logs
      .map((log) => {
        try {
          return factoryInterface.parseLog({
            topics: log.topics as string[],
            data: log.data,
          });
        } catch (e) {
          return null;
        }
      })
      .filter((event) => event && event.name === "PiggyCreated")[0];

    if (createdEvent) {
      const piggyAddress = createdEvent.args.piggyAddress;
      console.log(`Piggy bank created at address: ${piggyAddress}`);
      console.log(
        `Match with prediction: ${
          piggyAddress.toLowerCase() === predictedAddress.toLowerCase()
        }`
      );

      // Get user's piggy banks
      const userPiggies = await factory.getUserPiggies(deployer.address);
      console.log(`User now has ${userPiggies.length} piggy bank(s)`);
    } else {
      console.log("Could not find PiggyCreated event in the logs");
    }

    // Verify contracts on Etherscan/block explorer if not on a local network
    if (network.name !== "hardhat" && network.name !== "localhost") {
      // Wait for block confirmations for verification
      const deployTx = factory.deploymentTransaction();
      if (deployTx) {
        console.log(
          `\nWaiting for transaction ${deployTx.hash} to be confirmed...`
        );

        // Wait for confirmations (10 is usually enough for most explorers)
        try {
          await deployTx.wait(10);
          console.log("Transaction confirmed with 10 blocks.");
        } catch (error) {
          console.log(
            "Error waiting for confirmations, continuing anyway:",
            error
          );
        }

        // Additional delay to ensure the explorer API has indexed the contract
        const VERIFICATION_DELAY = 60000; // 60 seconds
        console.log(
          `Waiting an additional ${
            VERIFICATION_DELAY / 1000
          } seconds for the explorer to index the contract...`
        );
        await new Promise((resolve) => setTimeout(resolve, VERIFICATION_DELAY));
      }

      try {
        // Verify the factory contract
        console.log("Verifying PiggyFactory contract...");
        await hre.run("verify:verify", {
          address: factoryAddress,
          constructorArguments: [],
        });
        console.log("Contract verification complete!");
      } catch (verifyError) {
        console.log(
          "Verification failed, you can try to verify manually:",
          verifyError
        );
        console.log(
          `To verify manually, run: npx hardhat verify --network ${network.name} ${factoryAddress}`
        );
      }
    }

    // Print deployment summary
    console.log("\n=====================================================");
    console.log("DEPLOYMENT SUMMARY");
    console.log("=====================================================");
    console.log(`Network: ${network.name}`);
    console.log(`PiggyFactory: ${factoryAddress}`);
    if (createdEvent) {
      console.log(`Sample Piggy: ${createdEvent.args.piggyAddress}`);
    }
    console.log("=====================================================");
    console.log("Next steps:");
    console.log("1. Users can create new piggy banks using the factory");
    console.log("2. Deposit tokens (USDT, USDC, DAI) to save funds");
    console.log(
      "3. Withdraw after the duration period or use emergency withdraw with a penalty"
    );
    console.log("=====================================================");
  } catch (error) {
    console.error("Deployment failed:", error);
    process.exitCode = 1;
  }
}

// Execute deployment
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

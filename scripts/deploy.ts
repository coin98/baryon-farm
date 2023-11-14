import { ethers } from "hardhat";

async function main() {
	const SmartBaryFactory = await ethers.getContractFactory("SmartBaryFactory");
	const smartBaryFactory = await SmartBaryFactory.deploy(
		"SmartBaryFactory",
		"SBF",
		18
	);

	await smartBaryFactory.deployed();

	console.log(`Deploy to ${smartBaryFactory.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});

const hre = require("hardhat");

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

async function main() {
    const signer = await ethers.getSigner();
    delay(1000)

    console.log('Deploying from', signer.address)

    const oceanContract = await ethers.getContractFactory("Ocean", signer);
    const ocean = await oceanContract.deploy("");
    await ocean.deployed();
    delay(1000);

    console.log('Deployed ocean')
    console.log('Ocean contract address:', ocean.address)

    await hre.run("verify:verify", {
        address: ocean.address,
        constructorArguments: [""],
    });
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
});
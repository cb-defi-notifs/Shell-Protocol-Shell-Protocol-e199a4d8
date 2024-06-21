const hre = require("hardhat");
const shell = require("../utils-js");

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

const deployFactory = async (signer) => {
    const factoryContract = await ethers.getContractFactory("FractionalizerFactory", signer);
    const factory = await factoryContract.deploy();
    await factory.deployed();
    delay(1000);

    console.log('Deployed Fractionalizer Factory')
    console.log('Fractionalizer Factory address:', factory.address)

    await hre.run("verify:verify", {
        address: factory.address,
        constructorArguments: [],
    });

    return factory
}

const deployFractionalizer = async (factory, oceanAddress, collectionAddress, exchangeRate, is721) => {

    await factory.deploy(oceanAddress, collectionAddress, exchangeRate, is721)

    const fractionalizerAddress = await factory.getFractionalizer(collectionAddress)

    console.log('Deployed fractionalizer for', collectionAddress)
    console.log('Fractionalizer address:', fractionalizerAddress)

    return fractionalizerAddress
}

const fractionalize721 = async(signer, oceanAddress, nftAddress, fractionalizerAddress, nftID) => {
    const ocean = await hre.ethers.getContractAt("Ocean", oceanAddress)
    const fractionalizer = await hre.ethers.getContractAt("Fractionalizer721", fractionalizerAddress);
    const fungibleTokenID = await fractionalizer.fungibleTokenId();
    const interactions = [
        shell.interactions.wrapERC721({
            address: nftAddress, 
            id: nftID
        }),
        shell.interactions.computeOutputAmount({
            address: fractionalizerAddress,
            inputToken: shell.utils.calculateWrappedTokenId({address: nftAddress, id: nftID}),
            outputToken: fungibleTokenID,
            specifiedAmount: 1,
            metadata: ethers.utils.hexZeroPad(nftID, 32)
        })
    ]

    await shell.executeInteractions({
        ocean,
        signer,
        interactions: interactions
    });

    console.log("Fungible token amount", await ocean.balanceOf(signer.address, fungibleTokenID))

    await hre.run("verify:verify", {
        address: fractionalizerAddress,
        constructorArguments: [
            oceanAddress,
            nftAddress,
            exchangeRate
        ],
    });

}

const fractionalize1155 = async(signer, oceanAddress, nftAddress, fractionalizerAddress, nftID, nftAmount) => {
    const ocean = await hre.ethers.getContractAt("Ocean", oceanAddress)
    const fractionalizer = await hre.ethers.getContractAt("Fractionalizer1155", fractionalizerAddress);
    let fungibleTokenID = await fractionalizer.fungibleTokenIds(shell.utils.calculateWrappedTokenId({address: nftAddress, id: nftID}));
    if(fungibleTokenID == 0){
        const nonce = await fractionalizer.registeredTokenNonce();
        fungibleTokenID = shell.utils.calculateWrappedTokenId({address: fractionalizerAddress, id: nonce})
    }
    const nftContract = await hre.ethers.getContractAt("ERC1155", nftAddress);
    const approvalStatus = await nftContract.isApprovedForAll(signer.address, oceanAddress)
    if(!approvalStatus){
        await nftContract.setApprovalForAll(oceanAddress, true)
    }
    const interactions = [
        shell.interactions.wrapERC1155({
            address: nftAddress, 
            id: nftID,
            amount: nftAmount
        }),
        shell.interactions.computeOutputAmount({
            address: fractionalizerAddress,
            inputToken: shell.utils.calculateWrappedTokenId({address: nftAddress, id: nftID}),
            outputToken: fungibleTokenID,
            specifiedAmount: nftAmount,
            metadata: ethers.utils.hexZeroPad(nftID, 32)
        })
    ]

    await shell.executeInteractions({
        ocean,
        signer,
        interactions: interactions
    });

    console.log("Fungible token amount", await ocean.balanceOf(signer.address, fungibleTokenID))

    await hre.run("verify:verify", {
        address: fractionalizerAddress,
        constructorArguments: [
            oceanAddress,
            nftAddress,
            exchangeRate
        ],
    });

}

async function main() {
    const signer = await ethers.getSigner();
    delay(1000)

    console.log('Deploying from', signer.address)
    console.log('Deployer ETH balance', ethers.utils.formatEther(await ethers.provider.getBalance(signer.address)))

    const factory = await deployFactory(signer)
    // const factory = await hre.ethers.getContractAt("FractionalizerFactory", "FACTORY_ADDRESS_HERE")

    const oceanAddress = ''
    const nftAddress = ''
    const exchangeRate = hre.ethers.utils.parseUnits('100')
    const is721 = true

    const fractionalizerAddress = await deployFractionalizer(factory, oceanAddress, nftAddress, exchangeRate, is721)

    await fractionalize721(signer, oceanAddress, nftAddress, fractionalizerAddress, 0);
    // await fractionalize1155(signer, oceanAddress, nftAddress, fractionalizerAddress, 0, 1)
    
}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
});
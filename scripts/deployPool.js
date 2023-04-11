const hre = require("hardhat");
const shell = require("../utils-js");
const { calculateWrappedTokenId } = require("../utils-js/utils");

const ONE = ethers.utils.parseEther('1')
const ABDK_ONE = ethers.BigNumber.from(2).pow(64);

const deployProteus = async (signer, ocean, tokens, ms, _as, bs, ks, initialLPSupply) => {

    const init = []

    let ethAmount = 0;
    
    for(let i = 0; i < tokens.length; i++){
        if(!tokens[i].wrapped && tokens[i].address !== 'Ether'){
            const tokenContract = await hre.ethers.getContractAt("ERC20", tokens[i].address);
            delay(1000);
            await tokenContract.connect(signer).approve(ocean.address, tokens[i].intialDeposit);
            delay(1000);
            init.push(shell.interactions.wrapERC20({address: tokens[i].address, amount: tokens[i].intialDeposit}));
        } else if(tokens[i].address == 'Ether'){
            // Wrap ETH into ocean
            await ocean.connect(signer).doMultipleInteractions([], [tokens[i].oceanID], {value: tokens[i].intialDeposit});
            delay(1000);
        }
    }

    console.log('Approved tokens')

    const proxyContract = await ethers.getContractFactory("LiquidityPoolProxy", signer);
    const proteusContract = await ethers.getContractFactory("Proteus", signer);

    const proxy = await proxyContract.deploy(
        tokens[0].oceanID,
        tokens[1].oceanID,
        ocean.address,
        initialLPSupply
    );
    delay(1000);
    await proxy.deployed();
    delay(1000);

    const proteus = await proteusContract.deploy(ms, _as, bs, ks);
    delay(1000);
    await proteus.deployed();
    delay(1000);

    await proxy.connect(signer).setImplementation(proteus.address)
    delay(1000);

    console.log('Deployed liquidity pool proxy and implementation')

    const lpTokenId = await proxy.lpTokenId();
    delay(1000);

    tokens.forEach((token) => {
        init.push(shell.interactions.computeOutputAmount({
            address: proxy.address,
            inputToken: token.oceanID,
            outputToken: lpTokenId,
            specifiedAmount: token.intialDeposit,
            metadata: shell.constants.THIRTY_TWO_BYTES_OF_ZERO
        }));
    });

    await shell.executeInteractions({
        ocean,
        signer,
        interactions: init
    });
    delay(1000)

    console.log('Seeded pool with initial liquidity')
    console.log('Pool contract address:', proxy.address)
    console.log('LP token ID:', lpTokenId.toHexString())

    for(let i = 0; i < tokens.length; i++) {
        const token = tokens[i]
        console.log(token.address, ethers.utils.formatUnits(await ocean.connect(signer).balanceOf(proxy.address, token.oceanID)))
    }

    console.log('LP Supply', ethers.utils.formatUnits(await ocean.connect(signer).balanceOf(signer.address, lpTokenId)))

    await hre.run("verify:verify", {
        address: proxy.address,
        constructorArguments: [
            tokens[0].oceanID,
            tokens[1].oceanID,
            ocean.address,
            initialLPSupply
        ]
    });

    delay(1000)

    await hre.run("verify:verify", {
        address: proteus.address,
        constructorArguments: [
            ms,
            _as,
            bs,
            ks
        ]
    });

}

const changeParams = async (signer, proxyAddress, ms, _as, bs, ks) => { 
    const proteusContract = await ethers.getContractFactory("Proteus", signer);

    const proteus = await proteusContract.deploy(ms, _as, bs, ks);
    delay(1000);
    await proteus.deployed();
    delay(1000);

    const proxy = await hre.ethers.getContractAt("LiquidityPoolProxy", proxyAddress)

    await proxy.connect(signer).setImplementation(proteus.address)
    delay(1000);

    console.log("New implementation contract:", proteus.address)

    await hre.run("verify:verify", {
        address: proteus.address,
        constructorArguments: [
            ms,
            _as,
            bs,
            ks
        ]
    });

}

const freezePool = async (signer, proxyAddress, freeze) => {

    const proxy = await hre.ethers.getContractAt("LiquidityPoolProxy", proxyAddress)
    await proxy.connect(signer).freezePool(freeze);

    console.log("Pool frozen", await proxy.poolFrozen());

}

const getParams = async (signer, proxyAddress) => {

    const proxy = await hre.ethers.getContractAt("LiquidityPoolProxy", proxyAddress)
    const proteusAddress = proxy.implementation();

    const pool = await hre.ethers.getContractAt("Proteus", proteusAddress)

    const ms = (await pool.connect(signer).getSlopes()).map((_m) => ethers.utils.formatUnits(_m.mul(ONE).div(ABDK_ONE)))
    const _as = (await pool.connect(signer).getAs()).map((_a) => ethers.utils.formatUnits(_a.mul(ONE).div(ABDK_ONE)))
    const bs = (await pool.connect(signer).getBs()).map((_b) => ethers.utils.formatUnits(_b.mul(ONE).div(ABDK_ONE)))
    const ks = (await pool.connect(signer).getKs()).map((_k) => ethers.utils.formatUnits(_k.mul(ONE).div(ABDK_ONE)))

    console.log("Params", ms, _as, bs, ks)

    console.log(`Fee: ${200 / (await pool.BASE_FEE())}%`)

}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

async function main() {
    const signer = await ethers.getSigner();
    delay(1000)

    console.log('Deploying from', signer.address)
    console.log('Deployer ETH balance', ethers.utils.formatEther(await ethers.provider.getBalance(signer.address)))

    const ocean = await hre.ethers.getContractAt("Ocean", "OCEAN_ADDRESS_HERE")    
    delay(1000)

    const tokenOne = 'TOKEN_ADDRESS_HERE';
    const wrappedEtherID = (await ocean.WRAPPED_ETHER_ID()).toHexString();

    const tokens = [
        {
            address: tokenOne,
            oceanID: calculateWrappedTokenId({address: tokenOne, id: 0}),
            wrapped: false,
            intialDeposit: hre.ethers.utils.parseEther('100')
        },
        {
            address: "Ether",
            oceanID: wrappedEtherID,
            wrapped: false,
            intialDeposit: hre.ethers.utils.parseEther('1')
        } 
    ]

    const initialLPSupply = hre.ethers.utils.parseEther('100');

    for(let i = 0; i < tokens.length; i++) {
        const token = tokens[i]
        if(token.wrapped){
            console.log(token.address, ethers.utils.formatUnits(await ocean.connect(signer).balanceOf(signer.address, token.oceanID)))
        } else if(token.address !== 'Ether'){
            const tokenContract = await hre.ethers.getContractAt("ERC20", token.address);
            console.log(token.address, await tokenContract.connect(signer).balanceOf(signer.address))
        }
       
    }

    /* EDIT POOL DEPLOY PARAMETERS BELOW */

    const {ms, _as, bs, ks} = require("./params/constant-product");

    await deployProteus(signer, ocean, tokens, ms, _as, bs, ks, initialLPSupply);

    // await changeParams(signer, '', ms, _as, bs, ks)

    // await getParams(signer, '')

    // await freezePool(signer, '', false);

}

main()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e);
        process.exit(1);
});
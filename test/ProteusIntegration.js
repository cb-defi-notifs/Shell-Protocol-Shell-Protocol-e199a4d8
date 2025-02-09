const { ethers } = require("hardhat")
const { expect } = require("chai")
const shellv2 = require("../utils-js");

const decimals = "18"
const mintAmount = shellv2.utils.numberWithFixedDecimals({ number: "1000", decimals })

describe("Proteus Integration Test", () => {
    let proteusProxy
    let alice
    let bob
    let ocean
    const tokens = []
    const oceanIds = []

    before("Deploy Proteus", async () => {

        [alice, bob] = await ethers.getSigners()
        const oceanContract = await ethers.getContractFactory("Ocean", alice)
        ocean = await oceanContract.deploy("")

        const erc20Contract = await ethers.getContractFactory("ERC20MintsToDeployer")
        tokens[0] = await erc20Contract.deploy(mintAmount, decimals)
        oceanIds[0] = shellv2.utils.calculateWrappedTokenId({ address: tokens[0].address, id: 0 })
        tokens[1] = await erc20Contract.deploy(mintAmount, decimals)
        oceanIds[1] = shellv2.utils.calculateWrappedTokenId({ address: tokens[1].address, id: 0 })

        const wraps = [
            shellv2.interactions.unitWrapERC20({
                address: tokens[0].address,
                amount: "1000"
            }),
            shellv2.interactions.unitWrapERC20({
                address: tokens[1].address,
                amount: "1000"
            })
        ]

        await tokens[0].connect(alice).approve(ocean.address, mintAmount);
        await tokens[1].connect(alice).approve(ocean.address, mintAmount);

        await shellv2.executeInteractions({ ocean: ocean, signer: alice, interactions: wraps });

        const ProteusProxy = await ethers.getContractFactory("LiquidityPoolProxy", alice);

        proteusProxy = await ProteusProxy.deploy(
            shellv2.utils.calculateWrappedTokenId({ address: tokens[0].address, id: 0 }),
            shellv2.utils.calculateWrappedTokenId({ address: tokens[1].address, id: 0 }),
            ocean.address,
            mintAmount.div(5)
        )

        const ONE = ethers.utils.parseEther('1')
        const ABDK_ONE = ethers.BigNumber.from(2).pow(64);

        const ms = [

            ethers.BigNumber.from("25640378140000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("52631955610000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("176486037900000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("333371587500000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("538520049000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("818226110700000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("1222303769000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("1857512075000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("3000976136000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("5669257622000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("19011780730000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("39026042580000000000").mul(ABDK_ONE).div(ONE)

        ]

        const _as = [

            ethers.BigNumber.from("-37864635818100000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("994494574800000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("996568165800000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("998949728700000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999003351700000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999065034500000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("998979292200000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999069324400000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999115634600000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("998897196900000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("998645883200000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("998580698800000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("0")

        ]

        const bs = [

            ethers.BigNumber.from("0"),
            ethers.BigNumber.from("999132540000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999241988500000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999663642100000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999681583100000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999714939200000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999644436200000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999755147900000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999841839000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("999179148000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("997728241700000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("996418148900000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("-37974234723700000000").mul(ABDK_ONE).div(ONE)

        ]

        const ks = [

            ABDK_ONE,
            ethers.BigNumber.from("6254859434000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("9513601567000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("28746117460000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("30310444480000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("32671558110000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("28962612650000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("33907851000000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("38232547770000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("20723726300000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("10996470220000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("7973373974000000000000").mul(ABDK_ONE).div(ONE),
            ethers.BigNumber.from("997878522800000000").mul(ABDK_ONE).div(ONE)

        ]

        const proteusContract = await ethers.getContractFactory("Proteus", alice)

        const proteus = await proteusContract.deploy(ms, _as, bs, ks)
        await proteus.deployed()

        await proteusProxy
            .connect(alice)
            .setImplementation(proteus.address);

        const lpToken = await proteusProxy.lpTokenId();


        const init = tokens.map((token) => {
            return shellv2.interactions.computeOutputAmount({
                address: proteusProxy.address,
                inputToken: shellv2.utils.calculateWrappedTokenId({ address: token.address, id: 0 }),
                outputToken: lpToken,
                specifiedAmount: mintAmount.div(10),
                metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
            })
        });

        await shellv2.executeInteractions({
            ocean,
            signer: alice,
            interactions: init
        });

        await ocean.safeBatchTransferFrom(
            alice.address,
            bob.address,
            oceanIds,
            [mintAmount.div(10), mintAmount.div(10)],
            []
        )
    })

    it("Proteus has balances", async () => {
        const balances = await ocean.balanceOfBatch([proteusProxy.address, proteusProxy.address], oceanIds);
        expect(balances[0]).to.equal(mintAmount.div(10))
        expect(balances[1]).to.equal(mintAmount.div(10))
    })

    it("Alice has LP tokens", async () => {
        const balance = await ocean.balanceOf(alice.address, await proteusProxy.lpTokenId())
        expect(balance).to.equal(mintAmount.div(5))
    })

    it("Bob can swap", async () => {
        const swapOutputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[0],
            outputToken: oceanIds[1],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const swapOutputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[1],
            outputToken: oceanIds[0],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const swapInputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[0],
            outputToken: oceanIds[1],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const swapInputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[1],
            outputToken: oceanIds[0],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        expect(await shellv2.executeInteractions({
            ocean, signer: bob, interactions: [
                swapInputX, swapInputY, swapOutputX, swapOutputY
            ]
        })).to.have.property('hash')
    })

    it("Bob can deposit", async () => {
        const depositOutputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[0],
            outputToken: await proteusProxy.lpTokenId(),
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "2", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const depositOutputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[1],
            outputToken: await proteusProxy.lpTokenId(),
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "2", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const depositInputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[0],
            outputToken: await proteusProxy.lpTokenId(),
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "2", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const depositInputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: oceanIds[1],
            outputToken: await proteusProxy.lpTokenId(),
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "2", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        expect(await shellv2.executeInteractions({
            ocean, signer: bob, interactions: [
                depositInputX, depositInputY, depositOutputX, depositOutputY
            ]
        })).to.have.property('hash')
    })

    it("Bob can withdraw", async () => {
        const withdrawOutputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: await proteusProxy.lpTokenId(),
            outputToken: oceanIds[0],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const withdrawOutputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: await proteusProxy.lpTokenId(),
            outputToken: oceanIds[1],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const withdrawInputX = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: await proteusProxy.lpTokenId(),
            outputToken: oceanIds[0],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        const withdrawInputY = shellv2.interactions.computeOutputAmount({
            address: proteusProxy.address,
            inputToken: await proteusProxy.lpTokenId(),
            outputToken: oceanIds[1],
            specifiedAmount: shellv2.utils.numberWithFixedDecimals({ number: "1", decimals }),
            metadata: shellv2.constants.THIRTY_TWO_BYTES_OF_ZERO
        })
        expect(await shellv2.executeInteractions({
            ocean, signer: bob, interactions: [
                withdrawInputX, withdrawInputY, withdrawOutputX, withdrawOutputY
            ]
        })).to.have.property('hash')
    })
})
const { ethers } = require("hardhat");

const ABDK_ONE = ethers.BigNumber.from(2).pow(64);
const ONE = ethers.utils.parseEther('1')

const ms = [
    0.012769867615614864, 
    17000.0, 
    58289.49539132697
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const _as = [
    -3502.078122751312, 
    0.002630653388245341, 
    -0.007674453718253744, 
    0.0
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const bs = [
    0.0, 
    44.72110760017078, 
    -130.46571321031368, 
    316.87432143079013
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const ks = [
    1.0, 
    177501.0542197005, 
    58291.263792546626, 
    258353.8784607366
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

module.exports = { ms, _as, bs, ks }
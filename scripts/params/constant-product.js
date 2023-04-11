const { ethers } = require("hardhat");

const ABDK_ONE = ethers.BigNumber.from(2).pow(64);
const ONE = ethers.utils.parseEther('1')

const ms = [
    0.5,
    2
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const _as = [
   0,
   0,
   0
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const bs = [
    0,
    0,
    0
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const ks = [
    1,
    1,
    1
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

module.exports = { ms, _as, bs, ks }
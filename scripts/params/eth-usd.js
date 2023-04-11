const { ethers } = require("hardhat");

const ABDK_ONE = ethers.BigNumber.from(2).pow(64);
const ONE = ethers.utils.parseEther('1')

const ms = [
    0.01085679055020937, 
    1300.0,
    3585.2387754639894
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const _as = [
    -920.9825200829865,
    0.0076915367894991645,
    -0.028070420007789223,
    0
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const bs = [
    0,
    9.998997826348912,
    -36.491546010125994, 
    64.14761224536011
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

const ks = [
    1,
    9978.310634232354,
    3583.8806483258127,
    13643.984153955163
].map((value) => ethers.BigNumber.from(BigInt(value * 1e18).toString()).mul(ABDK_ONE).div(ONE))

module.exports = { ms, _as, bs, ks }
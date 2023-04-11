const ABDK_ONE = ethers.BigNumber.from(2).pow(64);
const ONE = ethers.utils.parseEther('1')

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

module.exports = { ms, _as, bs, ks }
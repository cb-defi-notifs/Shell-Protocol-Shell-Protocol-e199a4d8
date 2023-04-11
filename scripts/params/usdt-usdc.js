const ABDK_ONE = ethers.BigNumber.from(2).pow(64);
const ONE = ethers.utils.parseEther('1')

const ms = [
            
    ethers.BigNumber.from("4988524301616019").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("10093874228036957").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("134911549705007380").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("294951399049041830").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("507533406706403500").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("803608574748970200").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("1244396668893393600").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("1970342709159367000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("3390405890233086700").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("7411826856714478500").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("99016272187302080000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("199057878819721300000").mul(ABDK_ONE).div(ONE),
];



const _as = [
    ethers.BigNumber.from("-172448824556986536566").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("-24480104736984021945").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("968499015539816999").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("997044457633360953").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999176564587494283").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999760662223661838").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999775291339055225").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999832917765412267").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999754971067666352").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999715784844085922").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999337728227522208").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("952423716600508866").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("0")
];



const bs = [
    ethers.BigNumber.from("0"),
    ethers.BigNumber.from("738145554701094390").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("995020560258219360").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("998871670088073925").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999500538017117742").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999796987080251019").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999808743162822137").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999880453295821071").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999726871588214358").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("999594014384971278").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("996791924200965733").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("-3648458620457641623").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("-193235903384550331927").mul(ABDK_ONE).div(ONE)
];

const ks = [
    ABDK_ONE,
    ethers.BigNumber.from("6772180370810545500").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("4775908278027514000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("42658409603755594000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("131686706216427260000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("393821543135155100000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("418802120970220900000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("607778616655656100000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("336207321870940000000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("252404303563278840000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("45013559921375940000000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("37102710152459470000").mul(ABDK_ONE).div(ONE),
    ethers.BigNumber.from("892546756744152300").mul(ABDK_ONE).div(ONE)
];

module.exports = { ms, _as, bs, ks }
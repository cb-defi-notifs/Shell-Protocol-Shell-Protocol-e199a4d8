pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../ocean/Interactions.sol";
import "../../ocean/Ocean.sol";
import "../../mocks/ERC20MintsToDeployer.sol";
import "..//EvolvingInstrumentedProteus.sol";
import "../../proteus/LiquidityPoolProxy.sol";

/**
   Fork Test Suite for evolving proteus to test reverse swaps on each asset in a  pool, multiple swaps, deposits & withdrawals over time
   Here are the invariants associated with Evolving Proteus and we have tested
   1. pool balances considering the fee are as expected
   2. utility and utility / lp supply stays same after swap considering the fee
   3. utility and utility / lp supply increases after liquidity deposit
   4. utility and utility / lp supply increases after liquidity withdrawal
   5. when x price decreases over time & y price stays constant
   6. when x price increases over time & y price stays constant
   7. when y price decreases over time & x price stays constant
   8. when y price increases over time & x price stays constant
   9. when x & y prices both increase with time
   10. when x & y prices both decrease with time
   11. when x & y prices both stay constant
*/
contract ForkEvolvingProteus is Test {
  using ABDKMath64x64 for uint256;
  using ABDKMath64x64 for int256;
  using ABDKMath64x64 for int128;

  Ocean _ocean = Ocean(0xC32eB36f886F638fffD836DF44C124074cFe3584);
  ERC20MintsToDeployer _tokenA;
  address tokenOwner = 0x9b64203878F24eB0CDF55c8c6fA7D08Ba0cF77E5;
  EvolvingInstrumentedProteus _evolvingProteus;
  LiquidityPoolProxy _pool;

  uint256 _tokenA_OceanId; // deploying a new token
  uint256 _tokenB_OceanId = 68598205499637732940393479723998335974150219832588297998851264911405221787060;
  uint256 lpTokenId;
  bytes32 interactionIdToComputeOutputAmount;
  bytes32 interactionIdToWrapERC20TokenA;
  bytes32 interactionIdToUnWrapERC20TokenA;
  bytes32 interactionIdToUnWrapERC20TokenB;

  int256 constant BASE_FEE = 800; // base fee
  int256 constant FIXED_FEE = 10 ** 9; // rounding fee? idk
  uint256 constant T_DURATION =  3 days; 
  int128 constant ABDK_ONE = int128(int256(1 << 64));

  uint256 py_init_val;
  uint256 px_init_val;
  uint256 py_final_val;
  uint256 px_final_val;

  function setUp() public {
    vm.createSelectFork("https://arb1.arbitrum.io/rpc"); // Will start on latest block by default

    vm.prank(tokenOwner);
    _tokenA = new ERC20MintsToDeployer(500_000_000 ether, 18);

    _tokenA_OceanId = uint256(keccak256(abi.encodePacked(address(_tokenA), uint(0))));

    // funding the arb whale with eth
    vm.deal(tokenOwner, 500_000_000_000_000 ether);

    vm.prank(tokenOwner);
    _pool = new LiquidityPoolProxy(
      _tokenA_OceanId,
      _tokenB_OceanId,
      address(_ocean),
      10_000_000 ether
    );
    
    // Different price ranges that are used for testing
    // Note - Tests might fail due to a incompatible relation b/w the prices & the swap/deposit/withdrawal amounts this is a known relation i.e if the prices for a pool are high then the liquidity and the swap prices need to be higher too to avoid any bonding curve voilation checks e have in the contract (see the custo errors in the contract)
    // Note- some invariants for the reverse swap tests ight fail because of the fee so instead of user making money the pool makes money in some of those cases at the end of the reverse this is a known behaviour
    // Note - since we can't exactly predict the behavior when both x & y prices mov e in opposite directions hence we don't test those scenario's and consider that out of scope

    // x & y constant
    // py_init_val = 6951000000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 6951000000000000;
    // px_final_val = 69510000000000;
    
    // large values
    // py_final_val = 20000000000000000000000;
    // px_init_val = 11000000000000000000000;
    // py_init_val =  20000000000000000000000;
    // px_final_val = 11000000000000000000000;

    // x constant y increases
    // py_init_val = 695100000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 6951000000000000;
    // px_final_val = 69510000000000;

    // large values
    // py_final_val = 22000000000000000000000;
    // px_init_val = 11000000000000000000000;
    // py_init_val = 15000000000000000000000;
    // px_final_val = 11000000000000000000000;

    // x constant y decreases
    // py_init_val = 6951000000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 695100000000000;
    // px_final_val = 69510000000000;

    // large values
    // py_init_val = 20000000000000000000000;
    // px_init_val = 11000000000000000000000;
    // py_final_val = 15000000000000000000000;
    // px_final_val = 11000000000000000000000;

    //y constant x decreases
    // py_init_val = 6951000000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 6951000000000000;
    // px_final_val = 6951000000;

    // large values
    // py_final_val = 15000000000000000000000;
    // px_init_val =  14000000000000000000000;
    // py_init_val =  15000000000000000000000;
    // px_final_val = 11000000000000000000000;
    
    // y constant x increases
    py_init_val = 6951000000000000;
    px_init_val = 6951000000;
    py_final_val = 6951000000000000;
    px_final_val = 69510000000000;

    // large values
    // py_final_val = 15000000000000000000000;
    // px_final_val = 14000000000000000000000;
    // py_init_val = 15000000000000000000000;
    // px_init_val = 11000000000000000000000;

    // x & y both decrease
    // py_init_val = 6951000000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 695100000000000;
    // px_final_val = 6951000000000;

    // large values
    // py_init_val = 2000000000000000000000;
    // px_init_val = 1400000000000000000000;
    // py_final_val = 1500000000000000000000;
    // px_final_val = 1100000000000000000000;

    // x & y both increase
    // py_init_val = 6951000000000000;
    // px_init_val = 69510000000000;
    // py_final_val = 695100000000000000;
    // px_final_val = 695100000000000;

    // large values
    // py_final_val = 2000000000000000000000;
    // px_final_val = 1400000000000000000000;
    // py_init_val = 1500000000000000000000;
    // px_init_val = 1100000000000000000000;
    
    // using abdk math to handle the prices with precision
    int128 py_init = ABDKMath64x64.divu(py_init_val, 1e18);
    int128 px_init = ABDKMath64x64.divu(px_init_val, 1e18);
    int128 py_final = ABDKMath64x64.divu(py_final_val, 1e18);
    int128 px_final = ABDKMath64x64.divu(px_final_val, 1e18);

    vm.prank(tokenOwner);
    _evolvingProteus = new EvolvingInstrumentedProteus(
      py_init,
      px_init,
      py_final,
      px_final,
      T_DURATION
    );

    vm.prank(tokenOwner);
    _pool.setImplementation(address(_evolvingProteus));
    lpTokenId = _pool.lpTokenId();

    interactionIdToComputeOutputAmount = _fetchInteractionId(address(_pool), uint256(InteractionType.ComputeOutputAmount));
    interactionIdToWrapERC20TokenA = _fetchInteractionId(address(_tokenA), uint256(InteractionType.WrapErc20));
    interactionIdToUnWrapERC20TokenA = _fetchInteractionId(address(_tokenA), uint256(InteractionType.UnwrapErc20));
    interactionIdToUnWrapERC20TokenB = _fetchInteractionId(address(0), uint256(InteractionType.UnwrapEther));

    Interaction[] memory interactions = new Interaction[](3);
    // mint shell tokens
    interactions[0] = Interaction({
      interactionTypeAndAddress: interactionIdToWrapERC20TokenA,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: 100_000_000 ether,
      metadata: bytes32(0)
    });

    // adding liquidity
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenA_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: 100_000_000 ether,
      metadata: bytes32(0)
    });

    interactions[2] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenB_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: 80_000 ether,
      metadata: bytes32(0)
    });

    // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](3);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;
    ids[2] = lpTokenId;

    vm.prank(tokenOwner);
    // approving ocean to spend tokens
    IERC20(address(_tokenA)).approve(address(_ocean), 100_000_000 ether);

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions{ value: 80_000 ether }(interactions, ids);
  }

  /** 
    Logs all the curve equation related parameters
  */
  function _logPoolParams() internal {
    (int128 py_init, int128 px_init, int128 py_final, int128 px_final, uint t_init, uint t_final) = _evolvingProteus.config();
    int128 t = (block.timestamp - t_init).divu(t_final - t_init);

    (uint256 xBalanceAfterDeposit, uint256 yBalanceAfterDeposit) = _getBalances();
    int256 utility = _evolvingProteus.getUtility(int256(xBalanceAfterDeposit), int256(yBalanceAfterDeposit));

    emit log("utility");
    emit log_int(utility);
    emit log("a");
    emit log_int(_evolvingProteus.a());
    emit log("b");
    emit log_int(_evolvingProteus.b());
    emit log("px");
    emit log_int(_evolvingProteus.px());
    emit log("py");
    emit log_int(_evolvingProteus.py());
    emit log("t()");
    emit log_int(t);
    emit log("time % passed");
    emit log_uint((block.timestamp - t_init) * 100 / T_DURATION);
  }

  /**
    used to fetch the ocean interaction id for accounting purposes
  */
  function _fetchInteractionId(
    address token,
    uint256 interactionType
  ) internal pure returns (bytes32) {
    uint256 packedValue = uint256(uint160(token));
    packedValue |= interactionType << 248;
    return bytes32(abi.encode(packedValue));
  }

  /**
    fetch pool balances
  */
  function _getBalances() internal view returns (uint256 xBalance, uint256 yBalance) {
    address[] memory accounts = new address[](2);
    uint256[] memory ids = new uint256[](2);

    accounts[0] = accounts[1] = address(_pool);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;

    uint256[] memory result = _ocean.balanceOfBatch(accounts, ids);
    (xBalance, yBalance) = (result[0], result[1]);
  }

  /**
    fetch pool supply
  */
  function _getTotalSupply() internal view returns (uint256 supply) {
    supply = _pool.getTokenSupply(lpTokenId);
  }


  /**
    swap token a amount for token b
    @param _amount amount to swap
  */
  function _swapWithTokenAInputAmount(uint256 _amount) internal {
    // swap token a to token b
    (uint256 xBalanceBeforeSwap, uint256 yBalanceBeforeSwap) = _getBalances();
    int256 utilityBeforeSwap = _evolvingProteus.getUtility(int256(xBalanceBeforeSwap), int256(yBalanceBeforeSwap));
    int128 utilityPerLpBeforeSwap = uint256(utilityBeforeSwap).divu(_getTotalSupply());

    uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;

    {
    Interaction[] memory interactions = new Interaction[](3);
    // wrap
    interactions[0] = Interaction({
      interactionTypeAndAddress: interactionIdToWrapERC20TokenA,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: _amount,
      metadata: bytes32(0)
    });
    // swap
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenA_OceanId,
      outputToken: _tokenB_OceanId,
      specifiedAmount: _amount,
      metadata: bytes32(0)
    });

    // unwrap ether
    interactions[2] = Interaction({
      interactionTypeAndAddress: interactionIdToUnWrapERC20TokenB,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: type(uint256).max,
      metadata: bytes32(0)
    });

    // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](2);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;

    vm.prank(tokenOwner);
    _tokenA.approve(address(_ocean), _amount);

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions(interactions, ids);
    }
    
    (uint256 xBalanceAfterSwap, uint256 yBalanceAfterSwap) = _getBalances();
    int256 utilityAfterSwap = _evolvingProteus.getUtility(int256(xBalanceAfterSwap), int256(yBalanceAfterSwap));
    int128 utilityPerLpAfterSwap = uint256(utilityAfterSwap).divu(_getTotalSupply());
    
    // logging user balances, utility, pool parameters after the swap
    emit log("x before and after x->y swap");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(xBalanceAfterSwap);
    emit log("y before and after x->y swap");
    emit log_uint(yBalanceBeforeSwap);
    emit log_uint(yBalanceAfterSwap);
    emit log("utility before and after x->y swap");
    emit log_int(utilityBeforeSwap);
    emit log_int(utilityAfterSwap);
    emit log("utility per lp before and after swap");
    emit log_int(utilityPerLpBeforeSwap);
    emit log_int(utilityPerLpAfterSwap);
    emit log("a & b values");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());
    
    // assertion checks for utility, utility per lp, user token balances, curve parameters
    uint256 xBalDiff = xBalanceAfterSwap - xBalanceBeforeSwap;
    uint256 yBalDiff = yBalanceBeforeSwap - yBalanceAfterSwap;

    uint256 _tokenATraderBalanceAfterSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceAfterSwap = tokenOwner.balance;

    uint256 _tokenBBalDiff = _tokenBTraderBalanceAfterSwap - _tokenBTraderBalanceBeforeSwap;
    uint256 _tokenABalDiff = _tokenATraderBalanceBeforeSwap - _tokenATraderBalanceAfterSwap;

    assertWithinRounding(utilityAfterSwap, utilityBeforeSwap);
    assertWithinRounding(utilityPerLpAfterSwap, utilityPerLpBeforeSwap);
    assertWithinRounding(int256(_tokenBBalDiff), int256(yBalDiff));
    assertWithinRounding(int256(_tokenABalDiff), int256(xBalDiff));
    assertGt(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
    assertLt(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
    assertGt(_evolvingProteus.py(), _evolvingProteus.px());
  }

  /**
    swap token b amount for token a
    @param _amount amount to swap
  */
  function _swapWithTokenBInputAmount(uint256 _amount) internal {
    // swap token b to token a
    (uint256 xBalanceBeforeSwap, uint256 yBalanceBeforeSwap) = _getBalances();
    int256 utilityBeforeSwap = _evolvingProteus.getUtility(int256(xBalanceBeforeSwap), int256(yBalanceBeforeSwap));

    uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;
    int128 utilityPerLpBeforeSwap = uint256(utilityBeforeSwap).divu(_getTotalSupply());

    {
    Interaction[] memory interactions = new Interaction[](2);
    // swap
    interactions[0] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenB_OceanId,
      outputToken: _tokenA_OceanId,
      specifiedAmount: _amount,
      metadata: bytes32(0)
    });
    // unwrap
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToUnWrapERC20TokenA,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: type(uint256).max,
      metadata: bytes32(0)
    });

    // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](2);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions{ value: _amount }(interactions, ids);
    }

    (uint256 xBalanceAfterSwap, uint256 yBalanceAfterSwap) = _getBalances();

    int256 utilityAfterSwap = _evolvingProteus.getUtility(int256(xBalanceAfterSwap), int256(yBalanceAfterSwap));
    int128 utilityPerLpAfterSwap = uint256(utilityAfterSwap).divu(_getTotalSupply());

    uint256 _tokenATraderBalanceAfterSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceAfterSwap = tokenOwner.balance;

    uint256 xBalDiff = xBalanceBeforeSwap - xBalanceAfterSwap;
    uint256 yBalDiff = yBalanceAfterSwap - yBalanceBeforeSwap;

    // logging user balances, utility, pool parameters after the swap
    emit log("x before and after y->x swap");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(xBalanceAfterSwap);
    emit log("y before and after y->x swap");
    emit log_uint(yBalanceBeforeSwap);
    emit log_uint(yBalanceAfterSwap);
    emit log("utility before and after y->x swap");
    emit log_int(utilityBeforeSwap);
    emit log_int(utilityAfterSwap);
    emit log("utility per lp before and after swap");
    emit log_int(utilityPerLpBeforeSwap);
    emit log_int(utilityPerLpAfterSwap);
    emit log("a & b values");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    // assertion checks for utility, utility per lp, user token balances, curve parameters
    uint256 _tokenBBalDiff = _tokenBTraderBalanceBeforeSwap - _tokenBTraderBalanceAfterSwap;
    uint256 _tokenABalDiff = _tokenATraderBalanceAfterSwap - _tokenATraderBalanceBeforeSwap;

    assertWithinRounding(utilityAfterSwap, utilityBeforeSwap);
    assertWithinRounding(utilityPerLpAfterSwap, utilityPerLpBeforeSwap);
    assertWithinRounding(int256(_tokenBBalDiff), int256(yBalDiff));
    assertWithinRounding(int256(_tokenABalDiff), int256(xBalDiff));
    assertLt(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
    assertGt(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
    assertGt(_evolvingProteus.py(), _evolvingProteus.px());
  }

  /**
    add liquidity to the pool
    @param _amount token amount to deposit
  */
  function _addLiquidity(uint256 _amount) internal {
    (uint256 xBalanceBeforeDeposit, uint256 yBalanceBeforeDeposit) = _getBalances();
    int256 utilityBeforeDeposit = _evolvingProteus.getUtility(int256(xBalanceBeforeDeposit), int256(yBalanceBeforeDeposit));
    int128 utilityPerLpBeforeDeposit = uint256(utilityBeforeDeposit).divu(_getTotalSupply());

    Interaction[] memory interactions = new Interaction[](3);
    // wrap
    interactions[0] = Interaction({
      interactionTypeAndAddress: interactionIdToWrapERC20TokenA,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: _amount * 15,
      metadata: bytes32(0)
    });
    // deposit token a
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenA_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: _amount * 15,
      metadata: bytes32(0)
    });
    // deposit token b
    interactions[2] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenB_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: _amount,
      metadata: bytes32(0)
    });

    // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](3);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;
    ids[2] = lpTokenId;

    vm.prank(tokenOwner);
    _tokenA.approve(address(_ocean), _amount * 15);

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions{ value: _amount }(interactions, ids);

    (uint256 xBalanceAfterDeposit, uint256 yBalanceAfterDeposit) = _getBalances();
    int256 utilityAfterDeposit = _evolvingProteus.getUtility(int256(xBalanceAfterDeposit), int256(yBalanceAfterDeposit));
    int128 utilityPerLpAfterDeposit = uint256(utilityAfterDeposit).divu(_getTotalSupply());

    // logging user balances, utility, pool parameters after the swap
    emit log("x before and after deposit");
    emit log_uint(xBalanceBeforeDeposit);
    emit log_uint(xBalanceAfterDeposit);
    emit log("y before and after deposit");
    emit log_uint(yBalanceBeforeDeposit);
    emit log_uint(yBalanceAfterDeposit);
    emit log("utility before and after deposit");
    emit log_int(utilityBeforeDeposit);
    emit log_int(utilityAfterDeposit);
    emit log("utility per lp before and after deposit");
    emit log_int(utilityPerLpBeforeDeposit);
    emit log_int(utilityPerLpAfterDeposit);
    emit log("a & b values");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    // assertion checks for utility, utility per lp, curve parameters
    assertGt(utilityAfterDeposit, utilityBeforeDeposit);
    assertGt(utilityPerLpAfterDeposit, utilityPerLpBeforeDeposit);
    assertGt(_evolvingProteus.py(), _evolvingProteus.px());
  }

  /**
    remove liquidity from the pool
    @param _amount token amount to withdraw
  */
  function _removeLiquidity(uint256 _amount) internal {
    uint256 _lpBalanceBeforeDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    _addLiquidity(_amount);

    uint256 _lpBalanceAfterDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    uint256 _lpBalanceDiff = _lpBalanceAfterDeposit - _lpBalanceBeforeDeposit;

    (uint256 xBalanceBeforeWithdraw, uint256 yBalanceBeforeWithdraw) = _getBalances();
    int256 utilityBeforeWithdraw = _evolvingProteus.getUtility(int256(xBalanceBeforeWithdraw), int256(yBalanceBeforeWithdraw));
    int128 utilityPerLpBeforeWithdraw = uint256(utilityBeforeWithdraw).divu(_getTotalSupply());
    
    // remove liquidity
    Interaction[] memory interactions = new Interaction[](4);
    // remove and get token a
    interactions[0] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: lpTokenId,
      outputToken: _tokenA_OceanId,
      specifiedAmount: _lpBalanceDiff / 2,
      metadata: bytes32(0)
    });
    // unwrap token a
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToUnWrapERC20TokenA,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: type(uint256).max,
      metadata: bytes32(0)
    });
    // remove and get token b
    interactions[2] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: lpTokenId,
      outputToken: _tokenB_OceanId,
      specifiedAmount: _lpBalanceDiff / 2,
      metadata: bytes32(0)
    });
    // unwrap token b
    interactions[3] = Interaction({
      interactionTypeAndAddress: interactionIdToUnWrapERC20TokenB,
      inputToken: 0,
      outputToken: 0,
      specifiedAmount: type(uint256).max,
      metadata: bytes32(0)
    });

     // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](3);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;
    ids[2] = lpTokenId;

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions(interactions, ids);

    (uint256 xBalanceAfterWithdrawal, uint256 yBalanceAfterWithdrawal) = _getBalances();
    int256 utilityAfterWithdraw = _evolvingProteus.getUtility(int256(xBalanceAfterWithdrawal), int256(yBalanceAfterWithdrawal));
    int128 utilityPerLpAfterWithdraw = uint256(utilityAfterWithdraw).divu(_getTotalSupply());

    // logging user balances, utility, pool parameters after the swap
    emit log("x before and after withdrawal");
    emit log_uint(xBalanceBeforeWithdraw);
    emit log_uint(xBalanceAfterWithdrawal);
    emit log("y before and after withdrawal");
    emit log_uint(yBalanceBeforeWithdraw);
    emit log_uint(yBalanceAfterWithdrawal);
    emit log("utility before and after withdrawal");
    emit log_int(utilityBeforeWithdraw);
    emit log_int(utilityAfterWithdraw);
    emit log("utility per lp before and after withdrawal");
    emit log_int(utilityPerLpBeforeWithdraw);
    emit log_int(utilityPerLpAfterWithdraw);
    emit log("a & b values");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    // assertion checks for utility, utility per lp, curve parameters
    assertGt(utilityBeforeWithdraw, utilityAfterWithdraw);
    assertLt(utilityPerLpBeforeWithdraw, utilityPerLpAfterWithdraw);
    assertGt(_evolvingProteus.py(), _evolvingProteus.px());
  }


  /**
    test to check a reverse swap i.e
    at time t0 swap y -> x
    at time t1 swap x -> y
    Note : The test assertions are based on invariants mentioned below but some invariant assertions might fail due to the fee and there might be small differences in the asserted values

    @param _amount token amount to withdraw
  */
  function testReverseSwapY(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 50 ether, 5000 ether);
    _time = bound(_time, 100, T_DURATION);

    if (tokenOwner.balance > _amount ) {
      // swap first from b -> a & a -> b

      (,uint256 yBalanceBeforeSwap) = _getBalances();
      uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;
      uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);

      _swapWithTokenBInputAmount(_amount);
      uint256 _tokenATraderBalanceAfterSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
      uint256 _diffAmount = _tokenATraderBalanceAfterSwap - _tokenATraderBalanceBeforeSwap;

      _logPoolParams();
      vm.warp(block.timestamp + _time);
      _swapWithTokenAInputAmount(_diffAmount);
      _logPoolParams();

      (,uint256 yBalanceAfterSwap) = _getBalances();
      uint256 _tokenBTraderBalanceAfterSwap = tokenOwner.balance;
   
      // assertion for invariants based on the price confgurations
      if (px_final_val < px_init_val && py_final_val < py_init_val) {
          assertLe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertGe(yBalanceAfterSwap, yBalanceBeforeSwap);
      } else if (px_final_val > px_init_val && py_final_val > py_init_val) {
          assertGe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertLe(yBalanceAfterSwap, yBalanceBeforeSwap);
      } else if (px_final_val < px_init_val && py_final_val == py_init_val) {
          assertLe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertGe(yBalanceAfterSwap, yBalanceBeforeSwap);
      }  else if (px_final_val > px_init_val && py_final_val == py_init_val) {
          assertGe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertLe(yBalanceAfterSwap, yBalanceBeforeSwap);
      } else if (px_final_val == px_init_val && py_final_val < py_init_val) {
          assertLe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertGe(yBalanceAfterSwap, yBalanceBeforeSwap);
      } else if (px_final_val == px_init_val && py_final_val > py_init_val) {
          assertGe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertLe(yBalanceAfterSwap, yBalanceBeforeSwap);
      } else {
          assertLe(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
          assertGe(yBalanceAfterSwap, yBalanceBeforeSwap);
      }
    }
  }

  /**
    test to check a reverse swap i.e
    at time t0 swap x -> y
    at time t1 swap y -> x
    Note : The test assertions are based on invariants mentioned below but some invariant assertions might fail due to the fee and there might be small differences in the asserted values

    @param _amount token amount to withdraw
  */
  function testReverseSwapX(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 50 ether, 5000 ether);
    _time = bound(_time, 100, T_DURATION);

    if ((IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount)) {
      // swap first from a -> b & b -> a

      (uint256 xBalanceBeforeSwap,) = _getBalances();
      uint _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
      uint _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;

      _swapWithTokenAInputAmount(_amount);
      uint _tokenBTraderBalanceAfterSwap = tokenOwner.balance;
      uint _diffAmount = _tokenBTraderBalanceAfterSwap - _tokenBTraderBalanceBeforeSwap;

      _logPoolParams();
      vm.warp(block.timestamp + _time);
      _swapWithTokenBInputAmount(_diffAmount);
      _logPoolParams();
      
      (uint256 xBalanceAfterSwap,) = _getBalances();
      uint256 _tokenATraderBalanceAfterSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);

      // assertion for invariants based on the price confgurations
      if (px_final_val < px_init_val && py_final_val < py_init_val) {
          assertGe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertLe(xBalanceAfterSwap, xBalanceBeforeSwap);
      } else if (px_final_val > px_init_val && py_final_val > py_init_val) {
          assertLe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertGe(xBalanceAfterSwap, xBalanceBeforeSwap);
      } else if (px_final_val < px_init_val && py_final_val == py_init_val) {
          assertGe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertLe(xBalanceAfterSwap, xBalanceBeforeSwap);
      }  else if (px_final_val > px_init_val && py_final_val == py_init_val) {
          assertLe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertGe(xBalanceAfterSwap, xBalanceBeforeSwap);
      } else if (px_final_val == px_init_val && py_final_val < py_init_val) {
          assertGe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertLe(xBalanceAfterSwap, xBalanceBeforeSwap);
      } else if (px_final_val == px_init_val && py_final_val > py_init_val) {
          assertLe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertGe(xBalanceAfterSwap, xBalanceBeforeSwap);
      } else {
          assertLe(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
          assertGe(xBalanceAfterSwap, xBalanceBeforeSwap);
      }
    }
  }

  /**
    test to swap multiple times in different directions
    @param _amount token amount to swap
  */
  function testMultipleSwaps(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
      _swapWithTokenBInputAmount(_amount);
      _logPoolParams();
      _swapWithTokenAInputAmount(_amount * 10_00);
      _logPoolParams();
    }
  }

  /**
    test to swap multiple times in different directions over different time periods
    @param _amount token amount to swap
    @param _time time duration
  */
  function testMultipleSwapsOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    _time = bound(_time, 0, T_DURATION);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 10_00);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 10_00);
    _logPoolParams();
    }
  }

  /**
    test to deposit multiple times
    @param _amount token amount to swap
  */
  function testDeposit(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    _addLiquidity(_amount);
    _logPoolParams();
    }
  }

  /**
    test to deposit multiple times over different time periods
    @param _amount token amount to deposit
    @param _time time duration
  */
  function testDepositOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    _time = bound(_time, 0, T_DURATION);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 10_00);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _addLiquidity(_amount);
    _logPoolParams();
    }
  }

  /**
    test to withdraw multiple times 
    @param _amount token amount to withdraw
  */
  function testWithdraw(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
    _swapWithTokenAInputAmount(_amount);
    _logPoolParams();
    _removeLiquidity(_amount);
    _logPoolParams();
    }
  }


  /**
    test to withdraw multiple times over different time periods
    @param _amount token amount to withdraw
    @param _time time duration
  */
  function testWithdrawOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 5000 ether);
    _time = bound(_time, 0, T_DURATION);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 10_00)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 10_00);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _removeLiquidity(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 10_00);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _removeLiquidity(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    }
  }
  
  // rounding assertions considering the fees
  function assertWithinRounding(int256 a0, int256 a1) internal {
    assertLe(
      (a0) - (a0 / BASE_FEE) - FIXED_FEE,
      a1,
      "not within less than rounding"
    );
    assertGe(
      (a0) + (a0 / BASE_FEE) + FIXED_FEE,
      a1,
      "not within greater than rounding"
    );
  }
}
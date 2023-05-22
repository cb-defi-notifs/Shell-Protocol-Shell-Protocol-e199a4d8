pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../ocean/Interactions.sol";
import "../../ocean/Ocean.sol";
import "../../mocks/ERC20MintsToDeployer.sol";
import "..//EvolvingInstrumentedProteus.sol";
import "../../proteus/LiquidityPoolProxy.sol";

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

  function setUp() public {
    vm.createSelectFork("https://arb1.arbitrum.io/rpc"); // Will start on latest block by default

    vm.prank(tokenOwner);
    _tokenA = new ERC20MintsToDeployer(100_000 ether, 18);

    _tokenA_OceanId = uint256(keccak256(abi.encodePacked(address(_tokenA), uint(0))));

    // funding the arb whale with eth
    vm.deal(tokenOwner, 500 ether);

    vm.prank(tokenOwner);
    _pool = new LiquidityPoolProxy(
      _tokenA_OceanId,
      _tokenB_OceanId,
      address(_ocean),
      500 ether
    );

    int128 price_y_init = ABDKMath64x64.divu(6951000000000000, 1e18);
    int128 price_x_init = ABDKMath64x64.divu(69510000000000, 1e18);
    int128 price_y_final = ABDKMath64x64.divu(6951000000000000, 1e18);
    int128 price_x_final = ABDKMath64x64.divu(6951000000, 1e18);

    vm.prank(tokenOwner);
    _evolvingProteus = new EvolvingInstrumentedProteus(
      price_y_init,
      price_x_init,
      price_x_final,
      price_y_final,
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
      specifiedAmount: 15000 ether,
      metadata: bytes32(0)
    });

    // adding liquidity
    interactions[1] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenA_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: 15000 ether,
      metadata: bytes32(0)
    });

    interactions[2] = Interaction({
      interactionTypeAndAddress: interactionIdToComputeOutputAmount,
      inputToken: _tokenB_OceanId,
      outputToken: lpTokenId,
      specifiedAmount: 250 ether,
      metadata: bytes32(0)
    });

    // erc1155 token id's for balance delta
    uint256[] memory ids = new uint256[](3);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;
    ids[2] = lpTokenId;

    vm.prank(tokenOwner);
    // approving ocean to spend tokens
    IERC20(address(_tokenA)).approve(address(_ocean), 15000 ether);

    vm.prank(tokenOwner);
    _ocean.doMultipleInteractions{ value: 250 ether }(interactions, ids);
  }

  function _logPoolParams() internal {
    (int128 a_init, int128 b_init, int128 a_final, int128 b_final, uint t_init, uint t_final) = _evolvingProteus.config();
    int128 t = (block.timestamp - t_init).divu(t_final - t_init);

    (uint256 xBalanceAfterDeposit, uint256 yBalanceAfterDeposit) = _getBalances();
    int256 utility = _evolvingProteus.getUtility(int256(xBalanceAfterDeposit), int256(yBalanceAfterDeposit));

    emit log("utility");
    emit log_int(utility);
    emit log("a");
    emit log_int(_evolvingProteus.a());
    emit log("b");
    emit log_int(_evolvingProteus.b());
    emit log("a init");
    emit log_int(a_init);
    emit log("b init");
    emit log_int(b_init);
    emit log("a final");
    emit log_int(a_final);
    emit log("b final");
    emit log_int(b_final);
    emit log("current timestamp");
    emit log_uint(block.timestamp);
    emit log("t init");
    emit log_uint(t_init);
    emit log("t final");
    emit log_uint(t_final);
    emit log("time elasped");
    emit log_uint(block.timestamp - t_init);
    emit log("t()");
    emit log_int(t);
    emit log("3 days");
    emit log_uint(3 days);
    emit log("tf - ti");
    emit log_uint(t_final - t_init);
    emit log("time % passed");
    emit log_uint((block.timestamp - t_init) * 100 / T_DURATION);
  }

  function _fetchInteractionId(
    address token,
    uint256 interactionType
  ) internal pure returns (bytes32) {
    uint256 packedValue = uint256(uint160(token));
    packedValue |= interactionType << 248;
    return bytes32(abi.encode(packedValue));
  }

  function _getBalances() internal view returns (uint256 xBalance, uint256 yBalance) {
    address[] memory accounts = new address[](2);
    uint256[] memory ids = new uint256[](2);

    accounts[0] = accounts[1] = address(_pool);
    ids[0] = _tokenA_OceanId;
    ids[1] = _tokenB_OceanId;

    uint256[] memory result = _ocean.balanceOfBatch(accounts, ids);
    (xBalance, yBalance) = (result[0], result[1]);
  }

  function _getTotalSupply() internal view returns (uint256 supply) {
    supply = _pool.getTokenSupply(lpTokenId);
  }

  function _swapWithTokenAInputAmount(uint256 _amount) internal {
    // swap token a to token b
    (uint256 xBalanceBeforeSwap, uint256 yBalanceBeforeSwap) = _getBalances();
    int256 utilityBeforeSwap = _evolvingProteus.getUtility(int256(xBalanceBeforeSwap), int256(yBalanceBeforeSwap));
    int128 utilityPerLpBeforeSwap = uint256(utilityBeforeSwap).divu(_getTotalSupply());

    uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;
    emit log("x, y balances & utility before swap from token 1 to token 2");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(yBalanceBeforeSwap);
    emit log_int(utilityBeforeSwap);
    emit log("utility per lp before swap");
    emit log_int(utilityPerLpBeforeSwap);
    emit log("a & b values before swap from token 1 to token 2");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());
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

    emit log("x, y balances & utility after swap from token 1 to token 2");
    emit log_uint(xBalanceAfterSwap);
    emit log_uint(yBalanceAfterSwap);
    emit log_int(utilityAfterSwap);
    emit log("utility per lp after swap");
    emit log_int(utilityPerLpAfterSwap);
    emit log("a & b values after swap from token 1 to token 2");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());
    
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
  }

  function _swapWithTokenBInputAmount(uint256 _amount) internal {
    // swap token b to token a
    (uint256 xBalanceBeforeSwap, uint256 yBalanceBeforeSwap) = _getBalances();
    int256 utilityBeforeSwap = _evolvingProteus.getUtility(int256(xBalanceBeforeSwap), int256(yBalanceBeforeSwap));

    uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;
    int128 utilityPerLpBeforeSwap = uint256(utilityBeforeSwap).divu(_getTotalSupply());

    emit log("x, y balances & utility after swap from token 2 to token 1");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(yBalanceBeforeSwap);
    emit log_int(utilityBeforeSwap);
    emit log("utility per lp before swap");
    emit log_int(utilityPerLpBeforeSwap);
    emit log("a & b values before swap from token 2 to token 1");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());
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

    uint256 _tokenBBalDiff = _tokenBTraderBalanceBeforeSwap - _tokenBTraderBalanceAfterSwap;
    uint256 _tokenABalDiff = _tokenATraderBalanceAfterSwap - _tokenATraderBalanceBeforeSwap;

    emit log("x, y balances & utility after swap after b to a");
    emit log_uint(xBalanceAfterSwap);
    emit log_uint(yBalanceAfterSwap);
    emit log_int(utilityAfterSwap);
    emit log("utility per lp after swap");
    emit log_int(utilityPerLpAfterSwap);
    emit log("a & b values after swap from token 2 to token 1");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertWithinRounding(utilityAfterSwap, utilityBeforeSwap);
    assertWithinRounding(utilityPerLpAfterSwap, utilityPerLpBeforeSwap);
    assertWithinRounding(int256(_tokenBBalDiff), int256(yBalDiff));
    assertWithinRounding(int256(_tokenABalDiff), int256(xBalDiff));
    assertLt(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
    assertGt(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
  }

  function _addLiquidity(uint256 _amount) internal {
    (uint256 xBalanceBeforeDeposit, uint256 yBalanceBeforeDeposit) = _getBalances();
    int256 utilityBeforeDeposit = _evolvingProteus.getUtility(int256(xBalanceBeforeDeposit), int256(yBalanceBeforeDeposit));
    int128 utilityPerLpBeforeDeposit = uint256(utilityBeforeDeposit).divu(_getTotalSupply());

    emit log("x, y balances & utility before adding liquidity");
    emit log_uint(xBalanceBeforeDeposit);
    emit log_uint(yBalanceBeforeDeposit);
    emit log_int(utilityBeforeDeposit);
    emit log("utility per lp before deposit");
    emit log_int(utilityPerLpBeforeDeposit);
    emit log("a & b values before adding liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

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

    emit log("x, y balances & utility after adding liquidity");
    emit log_uint(xBalanceAfterDeposit);
    emit log_uint(yBalanceAfterDeposit);
    emit log_int(utilityAfterDeposit);
    emit log("utility per lp after deposit");
    emit log_int(utilityPerLpAfterDeposit);
    emit log("a & b values after adding liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertGt(utilityAfterDeposit, utilityBeforeDeposit);
    assertGt(utilityPerLpAfterDeposit, utilityPerLpBeforeDeposit);
  }

  function _removeLiquidity(uint256 _amount) internal {
    uint256 _lpBalanceBeforeDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    _addLiquidity(_amount);

    uint256 _lpBalanceAfterDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    uint256 _lpBalanceDiff = _lpBalanceAfterDeposit - _lpBalanceBeforeDeposit;

    (uint256 xBalanceBeforeWithdraw, uint256 yBalanceBeforeWithdraw) = _getBalances();
    int256 utilityBeforeWithdraw = _evolvingProteus.getUtility(int256(xBalanceBeforeWithdraw), int256(yBalanceBeforeWithdraw));
    int128 utilityPerLpBeforeWithdraw = uint256(utilityBeforeWithdraw).divu(_getTotalSupply());

    emit log("x, y balances & utility before removing liquidity");
    emit log_uint(xBalanceBeforeWithdraw);
    emit log_uint(yBalanceBeforeWithdraw);
    emit log_int(utilityBeforeWithdraw);
    emit log("utility per lp before withdraw");
    emit log_int(utilityPerLpBeforeWithdraw);
    emit log("a & b values before removing liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());
    
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

    emit log("x, y balances & utility after removing liquidity");
    emit log_uint(xBalanceAfterWithdrawal);
    emit log_uint(yBalanceAfterWithdrawal);
    emit log_int(utilityAfterWithdraw);
    emit log("utility per lp after withdraw");
    emit log_int(utilityPerLpAfterWithdraw);
    emit log("a & b values after removing liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertGt(utilityBeforeWithdraw, utilityAfterWithdraw);
    assertLt(utilityPerLpBeforeWithdraw, utilityPerLpAfterWithdraw);
  }

  function testMultipleSwaps(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
      _swapWithTokenBInputAmount(_amount);
      _logPoolParams();
      _swapWithTokenAInputAmount(_amount * 15);
      _logPoolParams();
    }
  }

  function testMultipleSwapsOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 15);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 15);
    _logPoolParams();
    }
  }

  function testDeposit(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    _addLiquidity(_amount);
    _logPoolParams();
    }
  }

  function testDepositOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 15);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _addLiquidity(_amount);
    _logPoolParams();
    }
  }

  function testWithdraw(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenAInputAmount(_amount);
    _logPoolParams();
    _removeLiquidity(_amount);
    _logPoolParams();
    }
  }

  function testWithdrawOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 15 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 15);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _removeLiquidity(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenAInputAmount(_amount * 15);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _removeLiquidity(_amount);
    _logPoolParams();
    vm.warp(block.timestamp + _time + 10);
    _swapWithTokenBInputAmount(_amount);
    _logPoolParams();
    }
  }

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
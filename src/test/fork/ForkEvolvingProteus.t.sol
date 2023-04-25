pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../ocean/Interactions.sol";
import "../../ocean/Ocean.sol";
import "..//EvolvingInstrumentedProteus.sol";
import "../../proteus/LiquidityPoolProxy.sol";

contract ForkEvolvingProteus is Test {
  Ocean _ocean = Ocean(0xC32eB36f886F638fffD836DF44C124074cFe3584);
  IERC20 _tokenA = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548); //arb
  address tokenOwner = 0x9b64203878F24eB0CDF55c8c6fA7D08Ba0cF77E5;
  EvolvingInstrumentedProteus _evolvingProteus;
  LiquidityPoolProxy _pool;

  uint256 _tokenA_OceanId = uint256(keccak256(abi.encodePacked(address(_tokenA), uint256(0))));
  uint256 _tokenB_OceanId = 68598205499637732940393479723998335974150219832588297998851264911405221787060;
  uint256 lpTokenId;
  bytes32 interactionIdToComputeOutputAmount;
  bytes32 interactionIdToWrapERC20TokenA;
  bytes32 interactionIdToUnWrapERC20TokenA;
  bytes32 interactionIdToUnWrapERC20TokenB;

  int256 constant BASE_FEE = 800; // base fee
  int256 constant FIXED_FEE = 10 ** 9; // rounding fee? idk
  uint256 constant T_DURATION = 3 days;

  function setUp() public {
    vm.createSelectFork("https://arb1.arbitrum.io/rpc"); // Will start on latest block by default
  
    // funding the arb whale with eth
    vm.deal(tokenOwner, 500 ether);

    vm.prank(tokenOwner);
    _pool = new LiquidityPoolProxy(
      _tokenA_OceanId,
      _tokenB_OceanId,
      address(_ocean),
      500 ether
    );

    int128 price_y_init = ABDKMath64x64.divu(15900000000000000, 1e18);
    int128 price_x_init = ABDKMath64x64.divu(159000000000000, 1e18);
    int128 price_y_final = ABDKMath64x64.divu(15900000000000000, 1e18);
    int128 price_x_final = ABDKMath64x64.divu(15900000000, 1e18);

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

  function _swapWithTokenAInputAmount(uint256 _amount) internal {
    // swap token a to token b
    (uint256 xBalanceBeforeSwap, uint256 yBalanceBeforeSwap) = _getBalances();
    int256 utilityBeforeSwap = _evolvingProteus.getUtility(int256(xBalanceBeforeSwap), int256(yBalanceBeforeSwap));

    uint256 _tokenATraderBalanceBeforeSwap = IERC20(address(_tokenA)).balanceOf(tokenOwner);
    uint256 _tokenBTraderBalanceBeforeSwap = tokenOwner.balance;
    emit log("x, y balances & utility before swap from token 1 to token 2");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(yBalanceBeforeSwap);
    emit log_int(utilityBeforeSwap);
    emit log("a & b values before swap from token 1 to token 2");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

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

    (uint256 xBalanceAfterSwap, uint256 yBalanceAfterSwap) = _getBalances();
    int256 utilityAfterSwap = _evolvingProteus.getUtility(int256(xBalanceAfterSwap), int256(yBalanceAfterSwap));

    emit log("x, y balances & utility after swap from token 1 to token 2");
    emit log_uint(xBalanceAfterSwap);
    emit log_uint(yBalanceAfterSwap);
    emit log_int(utilityAfterSwap);
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

    emit log("x, y balances & utility after swap from token 2 to token 1");
    emit log_uint(xBalanceBeforeSwap);
    emit log_uint(yBalanceBeforeSwap);
    emit log_int(utilityBeforeSwap);
    emit log("a & b values before swap from token 2 to token 1");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

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

    (uint256 xBalanceAfterSwap, uint256 yBalanceAfterSwap) = _getBalances();
    int256 utilityAfterSwap = _evolvingProteus.getUtility(int256(xBalanceAfterSwap), int256(yBalanceAfterSwap));

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
    emit log("a & b values after swap from token 2 to token 1");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertWithinRounding(utilityAfterSwap, utilityBeforeSwap);
    assertWithinRounding(int256(_tokenBBalDiff), int256(yBalDiff));
    assertWithinRounding(int256(_tokenABalDiff), int256(xBalDiff));
    assertLt(_tokenBTraderBalanceAfterSwap, _tokenBTraderBalanceBeforeSwap);
    assertGt(_tokenATraderBalanceAfterSwap, _tokenATraderBalanceBeforeSwap);
  }

  function _addLiquidity(uint256 _amount) internal {
    (uint256 xBalanceBeforeDeposit, uint256 yBalanceBeforeDeposit) = _getBalances();
    int256 utilityBeforeDeposit = _evolvingProteus.getUtility(int256(xBalanceBeforeDeposit), int256(yBalanceBeforeDeposit));

    emit log("x, y balances & utility before adding liquidity");
    emit log_uint(xBalanceBeforeDeposit);
    emit log_uint(yBalanceBeforeDeposit);
    emit log_int(utilityBeforeDeposit);
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

    emit log("x, y balances & utility after adding liquidity");
    emit log_uint(xBalanceAfterDeposit);
    emit log_uint(yBalanceAfterDeposit);
    emit log_int(utilityAfterDeposit);
    emit log("a & b values after adding liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertGt(utilityAfterDeposit, utilityBeforeDeposit);
  }

  function _removeLiquidity(uint256 _amount) internal {
    uint256 _lpBalanceBeforeDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    _addLiquidity(_amount);

    uint256 _lpBalanceAfterDeposit = _ocean.balanceOf(tokenOwner, lpTokenId);
    uint256 _lpBalanceDiff = _lpBalanceAfterDeposit - _lpBalanceBeforeDeposit;

    (uint256 xBalanceBeforeWithdraw, uint256 yBalanceBeforeWithdraw) = _getBalances();
    int256 utilityBeforeWithdraw = _evolvingProteus.getUtility(int256(xBalanceBeforeWithdraw), int256(yBalanceBeforeWithdraw));

    emit log("x, y balances & utility before removing liquidity");
    emit log_uint(xBalanceBeforeWithdraw);
    emit log_uint(yBalanceBeforeWithdraw);
    emit log_int(utilityBeforeWithdraw);
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

    emit log("x, y balances & utility after removing liquidity");
    emit log_uint(xBalanceAfterWithdrawal);
    emit log_uint(yBalanceAfterWithdrawal);
    emit log_int(utilityAfterWithdraw);
    emit log("a & b values after removing liquidity");
    emit log_int(_evolvingProteus.a());
    emit log_int(_evolvingProteus.b());

    assertGt(utilityBeforeWithdraw, utilityAfterWithdraw);
  }

  function testMultipleSwaps(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
      _swapWithTokenBInputAmount(_amount);
      _swapWithTokenAInputAmount(_amount * 15);
    }
  }

  function testMultipleSwapsOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION / 5);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    emit log("time logs during swaps");
    _swapWithTokenBInputAmount(_amount);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenAInputAmount(_amount * 15);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenBInputAmount(_amount);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenAInputAmount(_amount * 15);
    }
  }

  function testDeposit(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenBInputAmount(_amount);
    _addLiquidity(_amount);
    }
  }

  function testDepositOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION / 5);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    emit log("time logs during swaps");
    _swapWithTokenBInputAmount(_amount);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenAInputAmount(_amount * 15);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _addLiquidity(_amount);
    }
  }

  function testWithdraw(uint256 _amount) public {
    _amount = bound(_amount, 1 ether, 25 ether);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    _swapWithTokenAInputAmount(_amount);
    _removeLiquidity(_amount);
    }
  }

  function testWithdrawOverDuration(uint256 _amount, uint256 _time) public {
    _amount = bound(_amount, 1 ether, 25 ether);
    _time = bound(_time, T_DURATION / 8, T_DURATION / 5);

    if (tokenOwner.balance > _amount && (IERC20(address(_tokenA)).balanceOf(tokenOwner) > _amount * 15)) {
    emit log("time logs during swaps");
    _swapWithTokenBInputAmount(_amount);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenAInputAmount(_amount * 15);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _removeLiquidity(_amount);
     vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _swapWithTokenAInputAmount(_amount * 15);
    vm.warp(block.timestamp + _time);
    emit log("time % passed");
    emit log_uint((block.timestamp - _evolvingProteus.tInit()) * 100 / T_DURATION);
    _removeLiquidity(_amount);
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

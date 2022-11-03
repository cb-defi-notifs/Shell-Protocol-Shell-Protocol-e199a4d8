// SPDX-License-Identifier: MIT
// Cowri Labs Inc.

pragma solidity 0.8.10;

import "ds-test/test.sol";
import "forge-std/Vm.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./InstrumentedProteus.sol";
import "../proteus/Proteus.sol";

contract ProteusProperties is DSTest {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for uint256;
    using ABDKMath64x64 for int256;

    Vm public constant vm = Vm(HEVM_ADDRESS);

    uint256 public constant MAX_BALANCE = uint256(type(int256).max);
    uint256 public constant MIN_BALANCE = 10**12;
    uint256 public constant MIN_OPERATING_AMOUNT = 2 * 10**8;
    uint256 private constant MAX_BALANCE_AMOUNT_RATIO = 10**11;
    int256 public constant MAX_CHANGE_FACTOR = 10;
    uint8 public constant PERCENT_DECIMALS = 14;
    int256 constant BASE_FEE = 4000;
    int256 constant FIXED_FEE = 10**9;
    int128 MAX_M = 0x5f5e1000000000000000000;
    int128 MIN_M = 0x00000000000002af31dc461;

    int128[] ms;
    int128[] _as;
    int128[] bs;
    int128[] ks;

    // @dev DUT: Design Under Test
    InstrumentedProteus DUT;

    function setUp() public {
        ms = [
            
            ABDKMath64x64.divu(25640378140000000, 1e18),
            ABDKMath64x64.divu(52631955610000000, 1e18),
            ABDKMath64x64.divu(176486037900000000, 1e18),
            ABDKMath64x64.divu(333371587500000000, 1e18),
            ABDKMath64x64.divu(538520049000000000, 1e18),
            ABDKMath64x64.divu(818226110700000000, 1e18),
            ABDKMath64x64.divu(1222303769000000000, 1e18),
            ABDKMath64x64.divu(1857512075000000000, 1e18),
            ABDKMath64x64.divu(3000976136000000000, 1e18),
            ABDKMath64x64.divu(5669257622000000000, 1e18),
            ABDKMath64x64.divu(19011780730000000000, 1e18),
            ABDKMath64x64.divu(39026042580000000000, 1e18)
        ];


        _as = [
            ABDKMath64x64.divu(37864635818100000000, 1e18).neg(),
            ABDKMath64x64.divu(994494574800000000, 1e18),
            ABDKMath64x64.divu(996568165800000000, 1e18),
            ABDKMath64x64.divu(998949728700000000, 1e18),
            ABDKMath64x64.divu(999003351700000000, 1e18),
            ABDKMath64x64.divu(999065034500000000, 1e18),
            ABDKMath64x64.divu(998979292200000000, 1e18),
            ABDKMath64x64.divu(999069324400000000, 1e18),
            ABDKMath64x64.divu(999115634600000000, 1e18),
            ABDKMath64x64.divu(998897196900000000, 1e18),
            ABDKMath64x64.divu(998645883200000000, 1e18),
            ABDKMath64x64.divu(998580698800000000, 1e18),
            int128(0)
        ];

        bs = [
            int128(0),
            ABDKMath64x64.divu(999132540000000000, 1e18),
            ABDKMath64x64.divu(999241988500000000, 1e18),
            ABDKMath64x64.divu(999663642100000000, 1e18),
            ABDKMath64x64.divu(999681583100000000, 1e18),
            ABDKMath64x64.divu(999714939200000000, 1e18),
            ABDKMath64x64.divu(999644436200000000, 1e18),
            ABDKMath64x64.divu(999755147900000000, 1e18),
            ABDKMath64x64.divu(999841839000000000, 1e18),
            ABDKMath64x64.divu(999179148000000000, 1e18),
            ABDKMath64x64.divu(997728241700000000, 1e18),
            ABDKMath64x64.divu(996418148900000000, 1e18),
            ABDKMath64x64.divu(37974234723700000000, 1e18).neg()
        ];
        
        ks = [
            ABDKMath64x64.divu(1000000000000000000, 1e18),
            ABDKMath64x64.divu(6254859434000000000000, 1e18),
            ABDKMath64x64.divu(9513601567000000000000, 1e18),
            ABDKMath64x64.divu(28746117460000000000000, 1e18),
            ABDKMath64x64.divu(30310444480000000000000, 1e18),
            ABDKMath64x64.divu(32671558110000000000000, 1e18),
            ABDKMath64x64.divu(28962612650000000000000, 1e18),
            ABDKMath64x64.divu(33907851000000000000000, 1e18),
            ABDKMath64x64.divu(38232547770000000000000, 1e18),
            ABDKMath64x64.divu(20723726300000000000000, 1e18),
            ABDKMath64x64.divu(10996470220000000000000, 1e18),
            ABDKMath64x64.divu(7973373974000000000000, 1e18),
            ABDKMath64x64.divu(997878522800000000, 1e18)
        ];

        DUT = new InstrumentedProteus(ms, _as, bs, ks);
    }

    function testUtilityScaling(int256 x0, int256 y0) public {
        vm.assume(x0 >= int256(MIN_BALANCE) * 2);
        vm.assume(y0 >= int256(MIN_BALANCE) * 2);
        checkBoundary(x0, y0);
        uint256 i = DUT.findSlice(ms, x0, y0);
        try DUT.getUtility(x0, y0, _as[i], bs[i], ks[i]) returns (int256 u0) {
            try DUT.getUtility(x0 / 2, y0 / 2, _as[i], bs[i], ks[i]) returns (
                int256 u1
            ) {
                assertWithinRounding(u0 / 2, u1);
            } catch {}
        } catch {}
    }

    function testGetPointScaling(
        int256 x0,
        int256 y0,
        bool point
    ) public {
        vm.assume(x0 >= int256(MIN_BALANCE) * 2);
        vm.assume(y0 >= int256(MIN_BALANCE) * 2);
        checkBoundary(x0, y0);
        uint256 i = DUT.findSlice(ms, x0, y0);
        try DUT.getUtility(x0, y0, _as[i], bs[i], ks[i]) returns (int256 u0) {
            if (point) {
                try
                    DUT.getPointGivenXandUtility(
                        x0 / 2,
                        u0 / 2,
                        _as[i],
                        bs[i],
                        ks[i]
                    )
                returns (int256, int256 y1) {
                    assertWithinRounding(y0 / 2, y1);
                } catch {}
            } else {
                try
                    DUT.getPointGivenYandUtility(
                        y0 / 2,
                        u0 / 2,
                        _as[i],
                        bs[i],
                        ks[i]
                    )
                returns (int256 x1, int256) {
                    assertWithinRounding(x0 / 2, x1);
                } catch {}
            }
        } catch {}
    }

    function testSwapInput(
        uint256 x0,
        uint256 y0,
        uint256 inputAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(inputAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken inputToken = token ? SpecifiedToken.X : SpecifiedToken.Y;
        try DUT.swapGivenInputAmount(x0, y0, inputAmount, inputToken) returns (
            uint256 o0
        ) {
            uint256 x1;
            uint256 y1;
            SpecifiedToken opposite;
            if (inputToken == SpecifiedToken.X) {
                assertLt(o0, y0, "Pool cannot output more Y than it has");
                x1 = x0 + inputAmount;
                y1 = y0 - o0;
                opposite = SpecifiedToken.Y;
            } else {
                assertLt(o0, x0, "Pool cannot output more X than it has");
                y1 = y0 + inputAmount;
                x1 = x0 - o0;
                opposite = SpecifiedToken.X;
            }
            try DUT.swapGivenInputAmount(x1, y1, o0, opposite) returns (
                uint256 o1
            ) {
                if (inputToken == SpecifiedToken.X) {
                    assertLt(o1, x1, "Pool cannot output more X than it has");
                    assertEq(y1 + o0, y0, "Check earlier Y assignment");
                    assertGe(
                        x1 - o1,
                        x0,
                        "Back and forth swap should result in extra X"
                    );
                } else {
                    assertLt(o1, y1, "Pool cannot output more Y than it has");
                    assertEq(x1 + o0, x0, "Check earlier X assignment");
                    assertGe(
                        y1 - o1,
                        y0,
                        "Back and forth swap should result in extra Y"
                    );
                }
            } catch {}
        } catch {}
    }

    function testSwapOutput(
        uint256 x0,
        uint256 y0,
        uint256 outputAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(outputAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken outputToken = token
            ? SpecifiedToken.X
            : SpecifiedToken.Y;
        try
            DUT.swapGivenOutputAmount(x0, y0, outputAmount, outputToken)
        returns (uint256 i0) {
            uint256 x1;
            uint256 y1;
            SpecifiedToken opposite;
            if (outputToken == SpecifiedToken.X) {
                assertLt(
                    outputAmount,
                    x0,
                    "Pool cannot output more X than it has"
                );
                x1 = x0 - outputAmount;
                y1 = y0 + i0;
                opposite = SpecifiedToken.Y;
            } else {
                assertLt(
                    outputAmount,
                    y0,
                    "Pool cannot output more Y than it has."
                );
                y1 = y0 - outputAmount;
                x1 = x0 + i0;
                opposite = SpecifiedToken.X;
            }
            try DUT.swapGivenOutputAmount(x1, y1, i0, opposite) returns (
                uint256 i1
            ) {
                if (outputToken == SpecifiedToken.X) {
                    assertLt(i0, y1, "Pool cannot output more Y than it has");
                    assertEq(y1 - i0, y0, "Check earlier Y assignment");
                    assertGe(
                        x1 + i1,
                        x0,
                        "back and forth swap should result in extra X"
                    );
                } else {
                    assertLt(i0, x1, "Pool cannot output more X than it has");
                    assertEq(x1 - i0, x0, "Check earlier X assignment");
                    assertGe(
                        y1 + i1,
                        y0,
                        "back and forth swap should result in extra Y"
                    );
                }
            } catch (bytes memory error) {
                if (bytes4(error) == Proteus.BalanceError.selector) {
                    assertTrue(
                        x0 < MIN_BALANCE + MIN_OPERATING_AMOUNT ||
                            y0 < MIN_BALANCE + MIN_OPERATING_AMOUNT,
                        "rounding of the amount should cause a balance error"
                    );
                }
            }
        } catch {}
    }

    function testDepositOutputWithdrawInput(
        uint256 x0,
        uint256 y0,
        uint256 s0,
        uint256 mintedAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(s0 >= MIN_BALANCE);
        vm.assume(mintedAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken depositedToken = token
            ? SpecifiedToken.X
            : SpecifiedToken.Y;
        try
            DUT.depositGivenOutputAmount(
                x0,
                y0,
                s0,
                mintedAmount,
                depositedToken
            )
        returns (uint256 depositedAmount) {
            uint256 x1;
            uint256 y1;
            uint256 s1 = s0 + mintedAmount;
            if (depositedToken == SpecifiedToken.X) {
                x1 += depositedAmount;
                y1 = y0;
            } else {
                y1 += depositedAmount;
                x1 = x0;
            }
            try
                DUT.withdrawGivenInputAmount(
                    x1,
                    y1,
                    s1,
                    mintedAmount,
                    depositedToken
                )
            returns (uint256 withdrawnAmount) {
                assertLe(
                    withdrawnAmount,
                    depositedAmount,
                    "Depositing and withdrawing liquidity should not decrease value of pool"
                );
            } catch {}
        } catch {}
    }

    function testDepositInputWithdrawOutput(
        uint256 x0,
        uint256 y0,
        uint256 s0,
        uint256 depositedAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(s0 >= MIN_BALANCE);
        vm.assume(depositedAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken depositedToken = token
            ? SpecifiedToken.X
            : SpecifiedToken.Y;
        try
            DUT.depositGivenInputAmount(
                x0,
                y0,
                s0,
                depositedAmount,
                depositedToken
            )
        returns (uint256 mintedAmount) {
            uint256 x1;
            uint256 y1;
            uint256 s1 = s0 + mintedAmount;
            if (depositedToken == SpecifiedToken.X) {
                x1 += depositedAmount;
                y1 = y0;
            } else {
                y1 += depositedAmount;
                x1 = x0;
            }
            try
                DUT.withdrawGivenOutputAmount(
                    x1,
                    y1,
                    s1,
                    depositedAmount,
                    depositedToken
                )
            returns (uint256 burnedAmount) {
                assertGe(
                    burnedAmount,
                    mintedAmount,
                    "Depositing and withdrawing liquidity should not decrease value of pool"
                );
            } catch {}
        } catch {}
    }

    function testSwapDWInput(
        uint256 x0,
        uint256 y0,
        uint256 s0,
        uint256 inputAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(s0 >= MIN_BALANCE);
        vm.assume(inputAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken inputToken = token ? SpecifiedToken.X : SpecifiedToken.Y;
        
        try DUT.swapGivenInputAmount(x0, y0, inputAmount, inputToken) returns (uint256 o0) {

            uint256 x1;
            uint256 y1;
            uint256 startBal;

            SpecifiedToken opposite;

            if (inputToken == SpecifiedToken.X) {
                assertLt(o0, y0, "Pool cannot output more Y than it has");
                startBal = x0;
                x1 = x0 + inputAmount;
                y1 = y0 - o0;
                opposite = SpecifiedToken.Y;
            } else {
                assertLt(o0, x0, "Pool cannot output more X than it has");
                startBal = y0;
                y1 = y0 + inputAmount;
                x1 = x0 - o0;
                opposite = SpecifiedToken.X;
            }

            try DUT.depositGivenInputAmount(x1, y1, s0, o0, opposite) returns (uint256 mintedAmount) {
            
                uint256 s1 = s0 + mintedAmount;

                if (inputToken == SpecifiedToken.X) {
                    y1 += o0;
                    opposite = SpecifiedToken.X;
                } else {
                    x1 += o0;
                    opposite = SpecifiedToken.Y;
                }

                try DUT.withdrawGivenInputAmount(x1, y1, s1, mintedAmount, opposite) returns (uint256 o1) {
                    if (inputToken == SpecifiedToken.X) {
                        assertLt(o1, x1, "Pool cannot output more X than it has");
                        assertGe(
                            x1 - o1,
                            startBal,
                            "Back and forth swap should result in extra X"
                        );
                    } else {
                        assertLt(o1, y1, "Pool cannot output more Y than it has");
                        assertGe(
                            y1 - o1,
                            startBal,
                            "Back and forth swap should result in extra Y"
                        );
                    }
                } catch {}

                
            } catch {}
        } catch {}
    }

     function testSwapDWOutput(
        uint256 x0,
        uint256 y0,
        uint256 s0,
        uint256 outputAmount,
        bool token
    ) public {
        vm.assume(x0 >= MIN_BALANCE);
        vm.assume(y0 >= MIN_BALANCE);
        vm.assume(s0 >= MIN_BALANCE);
        vm.assume(outputAmount >= MIN_OPERATING_AMOUNT);
        SpecifiedToken outputToken = token ? SpecifiedToken.X : SpecifiedToken.Y;
        
        try DUT.swapGivenOutputAmount(x0, y0, outputAmount, outputToken) returns (uint256 i0) {

            uint256 x1;
            uint256 y1;
            uint256 startBal;

            SpecifiedToken opposite;

            if (outputToken == SpecifiedToken.X) {
                assertLt(outputAmount, x0, "Pool cannot output more X than it has");
                startBal = x0;
                x1 = x0 - outputAmount;
                y1 = y0 + i0;
                opposite = SpecifiedToken.Y;
            } else {
                assertLt(outputAmount, y0, "Pool cannot output more Y than it has");
                startBal = y0;
                y1 = y0 - outputAmount;
                x1 = x0 + i0;
                opposite = SpecifiedToken.X;
            }

            try DUT.withdrawGivenOutputAmount(x1, y1, s0, i0, opposite) returns (uint256 burnedAmount) {
            
                uint256 s1 = s0 - burnedAmount;

                if (outputToken == SpecifiedToken.X) {
                    y1 -= i0;
                    opposite = SpecifiedToken.X;
                } else {
                    x1 -= i0;
                    opposite = SpecifiedToken.Y;
                }

                try DUT.depositGivenOutputAmount(x1, y1, s1, burnedAmount, opposite) returns (uint256 i1) {
                    if (outputToken == SpecifiedToken.X) {
                        assertGe(
                            x1 + i1,
                            startBal,
                            "back and forth swap should result in extra X"
                        );
                    } else {
                        assertGe(
                            y1 + i1,
                            startBal,
                            "Back and forth swap should result in extra Y"
                        );
                    }
                } catch {}
            } catch {}
        } catch {}
    }

    function testEdgeSwaps(uint256 x0, uint256 y0, bool token) public {

        vm.assume(x0 > MIN_BALANCE && x0 < 1e27);
        vm.assume(y0 > MIN_BALANCE && y0 < 1e27);
        checkBoundary(int256(x0), int256(y0));

        SpecifiedToken inputToken = token ? SpecifiedToken.X : SpecifiedToken.Y;
        SpecifiedToken outputToken = token ? SpecifiedToken.Y : SpecifiedToken.X;

        uint256 maxInput = DUT.getSwapMax(int256(x0), int256(y0), token);
        vm.expectRevert();
        DUT.swapGivenInputAmount(x0, y0, maxInput, inputToken);

        uint256 maxOutput = (token ? y0 : x0) - MIN_BALANCE + 1;
        vm.expectRevert();
        DUT.swapGivenOutputAmount(x0, y0, maxOutput, outputToken);
    }

    function testSmallInput(uint256 x0, uint256 y0, bool token) public {

        vm.assume(x0 > MIN_BALANCE && x0 < MAX_BALANCE);
        vm.assume(y0 > MIN_BALANCE && y0 < MAX_BALANCE);
        checkBoundary(int256(x0), int256(y0));

        SpecifiedToken inputToken = token ? SpecifiedToken.X : SpecifiedToken.Y;
        SpecifiedToken outputToken = token ? SpecifiedToken.Y : SpecifiedToken.X;

        uint256 minInput = (token ? x0 : y0) / MAX_BALANCE_AMOUNT_RATIO;
        vm.expectRevert();
        DUT.swapGivenInputAmount(x0, y0, minInput, inputToken);

        uint256 minOutput = (token ? y0 : x0) / MAX_BALANCE_AMOUNT_RATIO;
        vm.expectRevert();
        DUT.swapGivenOutputAmount(x0, y0, minOutput, outputToken);

    }
    
    function testUtilityAlongSliceBoundary(uint256 x, uint8 mIndex) public {
        vm.assume(x < MAX_BALANCE);
        vm.assume(x > MIN_BALANCE);
        uint256 i = mIndex % (ms.length - 1);
        int256 xi = int256(x);
        // Make sure we won't overflow
        unchecked {
            int256 m = ms[i].toInt() + 1;
            int256 test = xi * m;
            if (test / xi != m) return;
        }
        int256 yi = ms[i].muli(xi);
        try DUT.getUtility(xi, yi, _as[i], bs[i], ks[i]) returns (int256 ru) {
            try
                DUT.getUtility(xi, yi, _as[i + 1], bs[i + 1], ks[i + 1])
            returns (int256 lu) {
                assertWithinRounding(ru, lu);
            } catch {}
        } catch {}
    }

    function testUtilityWithDeltaBalance(
        uint256 x,
        uint256 y,
        int128 delta,
        bool direction
    ) public {
        (
            int256 xi,
            int256 yi,
            int256 xf,
            int256 yf,
            uint256 i,
            uint256 j
        ) = assumes(x, y, delta, direction);
        vm.assume(i == j);
        try DUT.getUtility(xi, yi, _as[i], bs[i], ks[i]) returns (int256 ui) {
            try DUT.getUtility(xf, yf, _as[j], bs[j], ks[j]) returns (
                int256 uf
            ) {
                if (delta < 0) {
                    assertGe(ui, uf);
                } else {
                    assertLe(ui, uf);
                }
            } catch {}
        } catch {}
    }

    function testGetPointWithDeltaUtility(
        uint256 x,
        uint256 y,
        int128 delta,
        bool direction
    ) public {
        (int256 xi, int256 yi, uint256 i) = assumeXY(x, y);
        try DUT.getUtility(xi, yi, _as[i], bs[i], ks[i]) returns (int256 ui) {
            int256 uf = ui + delta;
            vm.assume(
                uf * MAX_CHANGE_FACTOR > ui && uf / MAX_CHANGE_FACTOR < ui
            );
            if (direction) {
                try
                    DUT.getPointGivenXandUtility(xi, ui, _as[i], bs[i], ks[i])
                returns (int256, int256 p0y) {
                    try
                        DUT.getPointGivenXandUtility(
                            xi,
                            ui + delta,
                            _as[i],
                            bs[i],
                            ks[i]
                        )
                    returns (int256 p1x, int256 p1y) {
                        checkBoundary(p1x, p1y);
                        uint256 j = DUT.findSlice(ms, p1x, p1y);
                        vm.assume(i == j);
                        if (delta < 0) {
                            assertLe(p1y, p0y);
                        } else {
                            assertGe(p1y, p0y);
                        }
                    } catch {}
                } catch {}
            } else {
                try
                    DUT.getPointGivenYandUtility(yi, ui, _as[i], bs[i], ks[i])
                returns (int256 p0x, int256) {
                    try
                        DUT.getPointGivenYandUtility(
                            yi,
                            ui + delta,
                            _as[i],
                            bs[i],
                            ks[i]
                        )
                    returns (int256 p1x, int256 p1y) {
                        checkBoundary(p1x, p1y);
                        uint256 j = DUT.findSlice(ms, p1x, p1y);
                        vm.assume(i == j);
                        if (delta < 0) {
                            assertLe(p1x, p0x);
                        } else {
                            assertGe(p1x, p0x);
                        }
                    } catch {}
                } catch {}
            }
        } catch {}
    }

    function testGetPointWithDeltaBalance(
        uint256 x,
        uint256 y,
        int128 delta,
        bool direction
    ) public {
        (
            int256 xi,
            int256 yi,
            int256 xf,
            int256 yf,
            uint256 i,
            uint256 j
        ) = assumes(x, y, delta, direction);
        vm.assume(i == j);
        try DUT.getUtility(xi, yi, _as[i], bs[i], ks[i]) returns (int256 ui) {
            if (direction) {
                try
                    DUT.getPointGivenXandUtility(xi, ui, _as[i], bs[i], ks[i])
                returns (int256, int256 p0y) {
                    try
                        DUT.getPointGivenXandUtility(
                            xf,
                            ui,
                            _as[i],
                            bs[i],
                            ks[i]
                        )
                    returns (int256, int256 p1y) {
                        // if x goes down and utility is constant, y should increase
                        if (delta < 0) {
                            assertGe(p1y, p0y);
                        } else {
                            assertLe(p1y, p0y);
                        }
                    } catch {}
                } catch {}
            } else {
                try
                    DUT.getPointGivenYandUtility(yi, ui, _as[i], bs[i], ks[i])
                returns (int256 p0x, int256) {
                    try
                        DUT.getPointGivenYandUtility(
                            yf,
                            ui,
                            _as[i],
                            bs[i],
                            ks[i]
                        )
                    returns (int256 p1x, int256) {
                        // if y goes down and utility is constant, x should increase
                        if (delta < 0) {
                            assertGe(p1x, p0x);
                        } else {
                            assertLe(p1x, p0x);
                        }
                    } catch {}
                } catch {}
            }
        } catch {}
    }

    function testRecovery(uint256 x, uint256 y) public {
        vm.assume(x > type(uint64).max);
        vm.assume(y > type(uint64).max);
        (int256 xi, int256 yi, uint256 si) = assumeXY(x, y);
        try DUT.getUtility(xi, yi, _as[si], bs[si], ks[si]) returns (
            int256 ui
        ) {
            try
                DUT.getPointGivenXandUtility(xi, ui, _as[si], bs[si], ks[si])
            returns (int256, int256 yf) {
                try
                    DUT.getPointGivenYandUtility(
                        yi,
                        ui,
                        _as[si],
                        bs[si],
                        ks[si]
                    )
                returns (int256 xf, int256) {
                    try
                        DUT.getUtility(xf, yf, _as[si], bs[si], ks[si])
                    returns (int256 uf) {
                        assertWithinRounding(ui, uf);
                    } catch {}
                } catch {}
            } catch {}
        } catch {}
    }

    function testFindSliceAndIsPointInSlice(int256 x, int256 y) public {
        vm.assume(x > 10**12 && y > 10**12);
        int256 t0 = y / x;
        int256 t1 = x / y;
        if (t0 < type(int64).max && t1 < type(int64).max) {
            int128 balanceRatio = ABDKMath64x64.divi(y, x);
            if (MIN_M <= balanceRatio && balanceRatio <= MAX_M) {
                uint256 i = DUT.findSlice(ms, x, y);
                (int128 mLeft, int128 mRight) = DUT.getSliceBoundaries(ms, i);
                int128 m = y.divi(x);
                assertLe(mRight, m);
                assertGe(mLeft, m);
                bool notInSlice = DUT.pointIsNotInSlice(ms, i, x, y);
                assertTrue(notInSlice == false);
            } else {
                vm.expectRevert(Proteus.BoundaryError.selector);
                DUT.findSlice(ms, x, y);
            }
        }
    }

    function testSqrt(int256 a, int256 b) public {
        vm.assume(a > 0 && b > 0);
        vm.assume(type(int256).max / a > a);
        int256 aSquared = a * a;

        // (a + 1)^2 = a^2 + 2a + 1
        // Any value between a^2 and (a+1)^2 - 1 inclusive should have
        // have a sqrt of a.
        // range [a^2, (a+1)^2 -1]
        // > range [a^2, a^2 + 2a + 1 - 1]
        // > range [0, 2a]
        // note that: n % n = 0, rand % n has range [0, n)
        // > range [0, 2a + 1)
        int256 rangeTilNextSquare = (a * 2) + 1;
        vm.assume(type(int256).max - aSquared > rangeTilNextSquare);
        int256 sqrt = int256(
            Math.sqrt(uint256((aSquared + (b % rangeTilNextSquare))))
        );
        assertEq(sqrt, a);

        int256 sqrtPlusOne = int256(
            Math.sqrt(uint256(aSquared + rangeTilNextSquare))
        );
        assertEq(sqrtPlusOne, a + 1);
    }

    function assumeXY(uint256 x, uint256 y)
        private
        returns (
            int256 xi,
            int256 yi,
            uint256 si
        )
    {
        vm.assume(x < MAX_BALANCE && y < MAX_BALANCE);
        vm.assume(x > MIN_BALANCE && y > MIN_BALANCE);
        xi = int256(x);
        yi = int256(y);

        checkBoundary(xi, yi);
        si = DUT.findSlice(ms, xi, yi);
    }

    function assumes(
        uint256 x,
        uint256 y,
        int256 delta,
        bool direction
    )
        private
        returns (
            int256 xi,
            int256 yi,
            int256 xf,
            int256 yf,
            uint256 si,
            uint256 sf
        )
    {
        (xi, yi, si) = assumeXY(x, y);

        if (direction) {
            yf = yi;
            if (delta < 0) {
                if (-delta >= xi) {
                    xf = xi;
                } else {
                    xf = xi; // + delta;
                }
            } else {
                if (type(int256).max - delta >= xi) {
                    xf = xi;
                } else {
                    xf = xi; // + delta;
                }
            }
            vm.assume(
                xi / MAX_CHANGE_FACTOR < xf && xf / MAX_CHANGE_FACTOR < xi
            );
        } else {
            xf = xi;
            if (delta < 0) {
                if (-delta >= xi) {
                    yf = yi;
                } else {
                    yf = yi; // + delta;
                }
            } else {
                if (type(int256).max - delta >= yi) {
                    yf = yi;
                } else {
                    yf = yi; // + delta;
                }
            }
            vm.assume(
                yi / MAX_CHANGE_FACTOR < yf && yf / MAX_CHANGE_FACTOR < yi
            );
        }

        checkBoundary(xf, yf);
        sf = DUT.findSlice(ms, xf, yf);
    }

    function checkBoundary(int256 x, int256 y) internal {
        vm.assume(x > int256(MIN_BALANCE) && y > int256(MIN_BALANCE));
        int256 t0 = y / x;
        int256 t1 = x / y;
        vm.assume(t0 < type(int64).max && t1 < type(int64).max);
        int128 balanceRatio = ABDKMath64x64.divi(y, x);
        vm.assume(MIN_M < balanceRatio && balanceRatio < MAX_M);
    }

    function assertWithinRounding(int256 a0, int256 a1) internal {
        assertLe((a0) - (a0 / BASE_FEE) - FIXED_FEE, a1);
        assertGe((a0) + (a0 / BASE_FEE) + FIXED_FEE, a1);
    }
}

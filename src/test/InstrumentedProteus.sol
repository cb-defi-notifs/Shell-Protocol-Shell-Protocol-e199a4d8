// SPDX-License-Identifier: MIT
// Cowri Labs Inc.

pragma solidity =0.8.10;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import {Proteus} from "../proteus/Proteus.sol";
import {SpecifiedToken} from "../proteus/ILiquidityPoolImplementation.sol";
// import "forge-std/console.sol";

contract InstrumentedProteus is Proteus {
    using ABDKMath64x64 for int128;
    using ABDKMath64x64 for int256;

    int128 private constant ABDK_ONE = int128(int256(1 << 64));
    int256 private constant MIN_BALANCE = 10**12;

    constructor(
        int128[] memory ms,
        int128[] memory _as,
        int128[] memory bs,
        int128[] memory ks
    ) Proteus(ms, _as, bs, ks) {}

    function swap(
        bool roundDirection,
        int256 specifiedAmount,
        int256 xi,
        int256 yi,
        SpecifiedToken specifiedToken
    ) public view returns (int256 computedAmount) {
        computedAmount = _swap(
            roundDirection,
            specifiedAmount,
            xi,
            yi,
            specifiedToken
        );
    }

    function getSwapMax(
        int256 xi, 
        int256 yi, 
        bool token
    ) public view returns (uint256 maxInput) {

        int128[] memory slopes = getSlopes();
        uint256 i = _findSlice(slopes, xi, yi);

        int128[] memory _as = getAs();
        int128[] memory bs = getBs();
        int128[] memory ks = getKs();
        int256 utility = _getUtility(xi, yi, _as[i], bs[i], ks[i]);
        
        int256 xf;
        int256 yf;

        i = token ? 0 : NUMBER_OF_SLICES - 1;

        (xf, yf) = token ? getPointGivenYandUtility(MIN_BALANCE, utility, _as[i], bs[i], ks[i]) : getPointGivenXandUtility(MIN_BALANCE, utility, _as[i], bs[i], ks[i]);

        int256 _max = token ? xf - xi : yf - yi;
        require(_max > 0);
        maxInput = uint256(_max) * 4;
 
    }

    function reserveTokenSpecified(
        SpecifiedToken specifiedToken,
        int256 specifiedAmount,
        bool roundDirection,
        int256 si,
        int256 xi,
        int256 yi
    ) public view returns (int256 computedAmount) {
        computedAmount = _reserveTokenSpecified(
            specifiedToken,
            specifiedAmount,
            roundDirection,
            si,
            xi,
            yi
        );
    }

    function lpTokenSpecified(
        SpecifiedToken specifiedToken,
        int256 specifiedAmount,
        bool roundDirection,
        int256 si,
        int256 xi,
        int256 yi
    ) public view returns (int256 computedAmount) {
        computedAmount = _lpTokenSpecified(
            specifiedToken,
            specifiedAmount,
            roundDirection,
            si,
            xi,
            yi
        );
    }

    function getUtility(
        int256 x,
        int256 y,
        int128 a,
        int128 b,
        int128 k
    ) public pure returns (int256 utility) {
        utility = _getUtility(x, y, a, b, k);
    }

    function getPointGivenXandUtility(
        int256 x,
        int256 utility,
        int128 a,
        int128 b,
        int128 k
    ) public pure returns (int256 xf, int256 yf) {
        (xf, yf) = _getPointGivenXandUtility(x, utility, a, b, k);
    }

    function getPointGivenYandUtility(
        int256 y,
        int256 utility,
        int128 a,
        int128 b,
        int128 k
    ) public pure returns (int256 xf, int256 yf) {
        (xf, yf) = _getPointGivenYandUtility(y, utility, a, b, k);
    }

    function findSlice(
        int128[] memory slopes,
        int256 x,
        int256 y
    ) public pure returns (uint256 index) {
        index = _findSlice(slopes, x, y);
    }

    function pointIsNotInSlice(
        int128[] memory slopes,
        uint256 currentSlice,
        int256 x,
        int256 y
    ) public pure returns (bool inSlice) {
        inSlice = _pointIsNotInSlice(slopes, currentSlice, x, y);
    }

    function getSliceBoundaries(int128[] memory slopes, uint256 index)
        public
        pure
        returns (int128 mLeft, int128 mRight)
    {
        (mLeft, mRight) = _getSliceBoundaries(slopes, index);
    }

    function next(uint256 currentSlice, int256 direction)
        public
        pure
        returns (uint256 nextSlice)
    {
        nextSlice = _next(currentSlice, direction);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IUniswapV2Factory.sol";
import "../libraries/TransferHelper.sol";

import "../interfaces/IUniswapV2Router02.sol";
import "../libraries/UniswapV2Library.sol";
import "../libraries/SafeMath.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../core/UniswapV2Factory.sol";
import "./FeeHandler.sol";

contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeMath for uint256;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "TENETSWAPV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "TENETSWAPV2Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "TENETSWAPV2Router: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);

        // Use scope to avoid stack too deep
        IUniswapV2Router02.LiquidityData memory liquidityData;
        liquidityData.user = to;
        liquidityData.token_a = tokenA;
        liquidityData.token_b = tokenB;
        liquidityData.amount_a = amountA;
        liquidityData.amount_b = amountB;
        liquidityData.token_a_decimal = IERC20(tokenA).decimals();
        liquidityData.token_b_decimal = IERC20(tokenB).decimals();
        liquidityData.new_pair_a_amount = IERC20(tokenA).balanceOf(pair);
        liquidityData.new_pair_b_amount = IERC20(tokenB).balanceOf(pair);
        liquidityData.lp_amount = liquidity;
        liquidityData.timestamp = uint64(block.timestamp);

        emit AddLiquidity(
            liquidityData.user,
            liquidityData.token_a,
            liquidityData.token_b,
            liquidityData.amount_a,
            liquidityData.amount_b,
            liquidityData.token_a_decimal,
            liquidityData.token_b_decimal,
            liquidityData.new_pair_a_amount,
            liquidityData.new_pair_b_amount,
            liquidityData.lp_amount,
            liquidityData.timestamp
        );
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        (amountToken, amountETH) =
            _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IUniswapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);

        // Use scope to avoid stack too deep
        IUniswapV2Router02.LiquidityData memory liquidityData;
        liquidityData.user = to;
        liquidityData.token_a = token;
        liquidityData.token_b = WETH;
        liquidityData.amount_a = amountToken;
        liquidityData.amount_b = amountETH;
        liquidityData.token_a_decimal = IERC20(token).decimals();
        liquidityData.token_b_decimal = 18; // WETH has 18 decimals
        liquidityData.new_pair_a_amount = IERC20(token).balanceOf(pair);
        liquidityData.new_pair_b_amount = IERC20(WETH).balanceOf(pair);
        liquidityData.lp_amount = liquidity;
        liquidityData.timestamp = uint64(block.timestamp);

        emit AddLiquidity(
            liquidityData.user,
            liquidityData.token_a,
            liquidityData.token_b,
            liquidityData.amount_a,
            liquidityData.amount_b,
            liquidityData.token_a_decimal,
            liquidityData.token_b_decimal,
            liquidityData.new_pair_a_amount,
            liquidityData.new_pair_b_amount,
            liquidityData.lp_amount,
            liquidityData.timestamp
        );
    }

    // Helper function to emit swap event
    function _emitSwapEvent(
        address user,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 feeAmount,
        uint256 feeRoyalty,
        uint256 buybackOkay,
        address pair
    ) internal {
        IUniswapV2Router02.SwapData memory swapData;
        swapData.user = user;
        swapData.input_token = inputToken;
        swapData.output_token = outputToken;
        swapData.input_amount = inputAmount;
        swapData.output_amount = outputAmount;
        swapData.input_decimal = inputToken == WETH ? 18 : IERC20(inputToken).decimals();
        swapData.output_decimal = outputToken == WETH ? 18 : IERC20(outputToken).decimals();
        swapData.fee_token = WETH;
        swapData.fee_amount = feeAmount;
        swapData.fee_royalty = feeRoyalty;
        swapData.buyback_okay = buybackOkay;
        swapData.new_pair_i_amount = IERC20(inputToken).balanceOf(pair);
        swapData.new_pair_o_amount = IERC20(outputToken).balanceOf(pair);
        swapData.timestamp = uint64(block.timestamp);

        emit Swap(
            swapData.user,
            swapData.input_token,
            swapData.output_token,
            swapData.input_amount,
            swapData.output_amount,
            swapData.input_decimal,
            swapData.output_decimal,
            swapData.fee_token,
            swapData.fee_amount,
            swapData.fee_royalty,
            swapData.buyback_okay,
            swapData.new_pair_i_amount,
            swapData.new_pair_o_amount,
            swapData.timestamp
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function _swapExternal(
        uint256 actualAmount,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) internal virtual returns (uint256[] memory amounts) {
        require(path[0] == WETH, "TENETSWAPV2Router: INVALID_PATH");
        IUniswapV2Router02 router02 = IUniswapV2Router02(payable(IUniswapV2Factory(factory).externalSwapRouter()));
        return router02.swapExactETHForTokens{value: actualAmount}(amountOutMin, path, to, deadline);
    }

    function _swapInternal(uint256 actualAmount, uint256 amountOutMin, address[] memory path, address to)
        internal
        virtual
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "TENETSWAPV2Router: INVALID_PATH");
        amounts = UniswapV2Library.getAmountsOut(factory, actualAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {
        // Ensure one of the tokens in the swap is BGB token
        address bgbToken = IUniswapV2Factory(factory).BGB();
        require(path[0] == bgbToken || path[path.length - 1] == bgbToken, "TENETSWAPV2Router: MUST_INCLUDE_BGB_TOKEN");

        if (path[0] == bgbToken) {
            // BGB as input - collect fee from input
            uint256 fee = amountIn.mul(FeeHandler.FEE_NUMERATOR).div(FeeHandler.FEE_DENOMINATOR);
            uint256 actualAmountIn = amountIn.sub(fee);

            // Execute swap with actual amount after fee
            amounts = UniswapV2Library.getAmountsOut(factory, actualAmountIn, path);
            require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), actualAmountIn
            );
            _swap(amounts, path, to);

            // Transfer fee to fee recipient
            if (fee > 0) {
                address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
                if (feeRecipient != address(0)) {
                    TransferHelper.safeTransferFrom(bgbToken, msg.sender, feeRecipient, fee);
                }
            }

            // Emit swap event
            address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
            _emitSwapEvent(
                msg.sender,
                path[0],
                path[path.length - 1],
                actualAmountIn,
                amounts[amounts.length - 1],
                fee,
                0, // no royalty in V3
                0, // no buyback in V3
                pair
            );

            return amounts;
        } else if (path[path.length - 1] == bgbToken) {
            // BGB as output - execute swap first, then collect fee from output
            amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

            // Calculate expected output after fee
            uint256 expectedBgbOutput = amounts[amounts.length - 1];
            uint256 fee = expectedBgbOutput.mul(FeeHandler.FEE_NUMERATOR).div(FeeHandler.FEE_DENOMINATOR);
            uint256 actualBgbToUser = expectedBgbOutput.sub(fee);

            require(actualBgbToUser >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
            );
            _swap(amounts, path, address(this));

            // Transfer fee to fee recipient
            if (fee > 0) {
                address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
                if (feeRecipient != address(0)) {
                    TransferHelper.safeTransfer(bgbToken, feeRecipient, fee);
                }
            }

            // Transfer actual BGB to user
            TransferHelper.safeTransfer(bgbToken, to, actualBgbToUser);

            // Update amounts array to reflect actual user output
            amounts[amounts.length - 1] = actualBgbToUser;

            // Emit swap event
            address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
            _emitSwapEvent(
                msg.sender,
                path[0],
                path[path.length - 1],
                amountIn,
                actualBgbToUser,
                fee,
                0, // no royalty in V3
                0, // no buyback in V3
                pair
            );

            return amounts;
        }
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WETH, "TENETSWAPV2Router: INVALID_PATH");
        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);

        // Use FeeHandler to process ETH fee
        (uint256 actualAmount, uint256 fee, uint256 feeRoyalty, uint256 leftFee) =
            FeeHandler.processExactETHForTokens(factory, path[path.length - 1], msg.value);

        amounts = UniswapV2Library.getAmountsOut(factory, actualAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(pair, amounts[0]));
        _swap(amounts, path, to);

        uint256 okayBalanceBefore =
            IERC20(IUniswapV2Factory(factory).BGB()).balanceOf(IUniswapV2Factory(factory).feeReceiver());
        if (leftFee > 0 && msg.sender != address(this)) {
            address[] memory feePath = new address[](2);
            feePath[0] = WETH;
            // Get buyback configuration from factory
            UniswapV2Factory factoryContract = UniswapV2Factory(factory);
            // Loop through buyback tokens
            for (uint256 i = 0; i < 5; i++) {
                address buyBackToken = factoryContract.buyBackTokens(i);
                uint16 buyBackPct = factoryContract.buyBackPcts(i);
                // Skip if token is zero address or percentage is 0
                if (buyBackToken == address(0) || buyBackPct == 0) {
                    continue;
                }
                // Calculate buyback amount based on percentage
                uint256 buyBackAmount = leftFee.mul(buyBackPct).div(10000);
                // Set buyback token in path and execute swap
                feePath[1] = buyBackToken;
                _swapExternal(buyBackAmount, 0, feePath, IUniswapV2Factory(factory).feeReceiver(), deadline);
            }
        }
        uint256 okayBalanceAfter =
            IERC20(IUniswapV2Factory(factory).BGB()).balanceOf(IUniswapV2Factory(factory).feeReceiver());

        _emitSwapEvent(
            msg.sender,
            WETH,
            path[path.length - 1],
            msg.value,
            amounts[amounts.length - 1],
            fee,
            feeRoyalty,
            okayBalanceAfter - okayBalanceBefore,
            pair
        );
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, "TENETSWAPV2Router: INVALID_PATH");
        address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, pair, amounts[0]);
        _swap(amounts, path, address(this));

        // Withdraw total WETH to ETH
        uint256 actualOutputAmount = amounts[amounts.length - 1];
        IWETH(WETH).withdraw(actualOutputAmount);
        // Use FeeHandler to withdraw WETH and distribute ETH with fee handling
        (uint256 fee, uint256 feeRoyalty, uint256 leftFee) =
            FeeHandler.processExactTokensForETH(factory, path[0], actualOutputAmount, to);

        uint256 okayBalanceBefore =
            IERC20(IUniswapV2Factory(factory).BGB()).balanceOf(IUniswapV2Factory(factory).feeReceiver());
        if (leftFee > 0) {
            address[] memory feePath = new address[](2);
            feePath[0] = WETH;
            // Get buyback configuration from factory
            UniswapV2Factory factoryContract = UniswapV2Factory(factory);
            // Loop through buyback tokens
            for (uint256 i = 0; i < 5; i++) {
                address buyBackToken = factoryContract.buyBackTokens(i);
                uint16 buyBackPct = factoryContract.buyBackPcts(i);
                // Skip if token is zero address or percentage is 0
                if (buyBackToken == address(0) || buyBackPct == 0) {
                    continue;
                }
                // Calculate buyback amount based on percentage
                uint256 buyBackAmount = leftFee.mul(buyBackPct).div(10000);
                // Set buyback token in path and execute swap
                feePath[1] = buyBackToken;
                _swapExternal(buyBackAmount, 0, feePath, IUniswapV2Factory(factory).feeReceiver(), deadline);
            }
        }
        uint256 okayBalanceAfter =
            IERC20(IUniswapV2Factory(factory).BGB()).balanceOf(IUniswapV2Factory(factory).feeReceiver());

        _emitSwapEvent(
            msg.sender,
            path[0],
            WETH,
            amountIn,
            actualOutputAmount,
            fee,
            feeRoyalty,
            okayBalanceAfter - okayBalanceBefore,
            pair
        );
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}

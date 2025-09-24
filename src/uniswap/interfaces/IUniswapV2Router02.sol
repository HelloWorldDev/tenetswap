// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./IUniswapV2Router01.sol";

interface IUniswapV2Router02 is IUniswapV2Router01 {
    struct SwapData {
        address user;
        address input_token;
        address output_token;
        uint256 input_amount;
        uint256 output_amount;
        uint8 input_decimal;
        uint8 output_decimal;
        address fee_token;
        uint256 fee_amount;
        uint256 fee_royalty;
        uint256 buyback_okay;
        uint256 new_pair_i_amount;
        uint256 new_pair_o_amount;
        uint64 timestamp;
    }

    struct LiquidityData {
        address user;
        address token_a;
        address token_b;
        uint256 amount_a;
        uint256 amount_b;
        uint256 new_pair_a_amount;
        uint256 new_pair_b_amount;
        uint8 token_a_decimal;
        uint8 token_b_decimal;
        uint256 lp_amount;
        uint64 timestamp;
    }

    event Swap(
        address user,
        address input_token,
        address output_token,
        uint256 input_amount,
        uint256 output_amount,
        uint8 input_decimal,
        uint8 output_decimal,
        address fee_token,
        uint256 fee_amount,
        uint256 fee_royalty,
        uint256 buyback_okay,
        uint256 new_pair_i_amount,
        uint256 new_pair_o_amount,
        uint64 timestamp
    );

    event AddLiquidity(
        address user,
        address token_a,
        address token_b,
        uint256 amount_a,
        uint256 amount_b,
        uint8 token_a_decimal,
        uint8 token_b_decimal,
        uint256 new_pair_a_amount,
        uint256 new_pair_b_amount,
        uint256 lp_amount,
        uint64 timestamp
    );
}

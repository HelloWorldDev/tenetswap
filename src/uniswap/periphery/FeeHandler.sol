// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IRoyaltyFactory.sol";
import "../libraries/SafeMath.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IWETH.sol";
import "../proxy/UniswapV2FactoryUpgradeable.sol";

library FeeHandler {
    using SafeMath for uint256;

    uint256 public constant FEE_NUMERATOR = 20;
    uint256 public constant ROYALTY_FEE_NUMERATOR = 500;
    uint256 public constant FEE_DENOMINATOR = 1000;

    function processExactETHForTokens(address factory, address token, uint256 msgValue)
        internal
        returns (uint256 actualAmount, uint256 fee, uint256 feeRoyalty, uint256 leftFee)
    {
        address royalty = IUniswapV2Factory(factory).tokenRoyalty(token);
        fee = msgValue.mul(FEE_NUMERATOR) / FEE_DENOMINATOR; // 2% fee

        if (royalty != address(0)) {
            feeRoyalty = fee.mul(ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR;
        } else {
            feeRoyalty = 0;
        }
        leftFee = fee.sub(feeRoyalty);
        actualAmount = msgValue.sub(fee);

        // Call royaltyFactory's addRoyaltyFee to transfer royalty fee
        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        if (royaltyFactory != address(0) && feeRoyalty > 0) {
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee{value: feeRoyalty}(token, feeRoyalty);
        }
    }

    function processExactTokensForETH(
        address factory,
        address token, // token (unused)
        uint256 totalAmount,
        address to
    ) internal returns (uint256 fee, uint256 feeRoyalty, uint256 leftFee) {
        address royalty = IUniswapV2Factory(factory).tokenRoyalty(token);

        fee = totalAmount.mul(FEE_NUMERATOR) / FEE_DENOMINATOR; // 2% fee

        if (royalty != address(0)) {
            // Calculate fee and actual amount for user
            feeRoyalty = fee.mul(ROYALTY_FEE_NUMERATOR) / FEE_DENOMINATOR;
        } else {
            feeRoyalty = 0;
        }
        leftFee = fee.sub(feeRoyalty);
        uint256 amountToUser = totalAmount.sub(fee);

        // Call royaltyFactory's addRoyaltyFee to transfer royalty fee
        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        if (royaltyFactory != address(0) && feeRoyalty > 0) {
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee{value: feeRoyalty}(token, feeRoyalty);
        }
        // Transfer remaining to user
        TransferHelper.safeTransferETH(to, amountToUser);
    }
}

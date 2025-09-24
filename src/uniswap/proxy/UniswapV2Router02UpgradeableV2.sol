// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./UniswapV2Router02Upgradeable.sol";

contract UniswapV2Router02UpgradeableV2 is UniswapV2Router02Upgradeable {
    using SafeMath for uint256;

    function _swapInternal2(uint256 actualAmount, uint256 amountOutMin, address[] memory path, address to)
        internal
        virtual
        returns (uint256[] memory amounts)
    {
        // Execute swap with actual amount after fee
        amounts = UniswapV2Library.getAmountsOut(factory, actualAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), actualAmount
        );
        _swap(amounts, path, to);
    }

    function _swapInternal2FromThis(uint256 actualAmount, uint256 amountOutMin, address[] memory path, address to)
        internal
        virtual
        returns (uint256[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsOut(factory, actualAmount, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        TransferHelper.safeTransfer(path[0], UniswapV2Library.pairFor(factory, path[0], path[1]), actualAmount);
        _swap(amounts, path, to);
    }

    function _processBgbInputV2(uint256 fee, address[] memory path)
        internal
        virtual
        returns (uint256 feeRoyalty, uint256 leftFee)
    {
        if (fee == 0) return (0, 0);

        address bgbToken = IUniswapV2Factory(factory).BGB();
        address mbToken = IUniswapV2Factory(factory).MB();
        address baseToken = path[path.length - 1];

        // feePath length is dynamic: when buyback token is MB, path is [BGB, MB];
        // otherwise path is [BGB, MB, buyBackToken]. We'll allocate per-iteration.
        leftFee = fee;

        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        address royalty = IRoyaltyFactory(royaltyFactory).getRoyalty(baseToken);
        feeRoyalty = 0;
        uint256 feeBuyBack = 0;

        if (royalty != address(0)) {
            feeRoyalty = fee.div(2);
            TransferHelper.safeTransferFrom(bgbToken, msg.sender, royaltyFactory, feeRoyalty);
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee(baseToken, feeRoyalty);
        }

        leftFee = leftFee.sub(feeRoyalty);
        feeBuyBack = leftFee.div(2);
        leftFee = leftFee.sub(feeBuyBack);

        for (uint256 i = 0; i < 5; i++) {
            address buyBackToken = UniswapV2FactoryUpgradeable(factory).buyBackTokens(i);
            uint16 buyBackPct = UniswapV2FactoryUpgradeable(factory).buyBackPcts(i);
            if (buyBackToken == address(0) || buyBackPct == 0) {
                continue;
            }
            uint256 buyBackAmount = feeBuyBack.mul(buyBackPct).div(10000);
            if (buyBackAmount == 0) continue;
            if (buyBackToken == mbToken) {
                address[] memory feePath2 = new address[](2);
                feePath2[0] = bgbToken;
                feePath2[1] = mbToken;
                _swapInternal2(buyBackAmount, 0, feePath2, IUniswapV2Factory(factory).feeReceiver());
            } else {
                address[] memory feePath3 = new address[](3);
                feePath3[0] = bgbToken;
                feePath3[1] = mbToken;
                feePath3[2] = buyBackToken;
                _swapInternal2(buyBackAmount, 0, feePath3, IUniswapV2Factory(factory).feeReceiver());
            }
        }

        address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
        if (feeRecipient != address(0) && leftFee > 0) {
            TransferHelper.safeTransferFrom(bgbToken, msg.sender, feeRecipient, leftFee);
        }
    }

    function _processBgbOutputV2(uint256 fee, address[] memory path)
        internal
        virtual
        returns (uint256 feeRoyalty, uint256 leftFee)
    {
        if (fee == 0) return (0, 0);

        address bgbToken = IUniswapV2Factory(factory).BGB();
        address mbToken = IUniswapV2Factory(factory).MB();
        require(path.length >= 1, "Fee: INVALID_PATH");
        address baseToken = path[0];

        // feePath length is dynamic: when buyback token is MB, path is [BGB, MB];
        // otherwise path is [BGB, MB, buyBackToken]. We'll allocate per-iteration.
        leftFee = fee;

        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        address royalty = IRoyaltyFactory(royaltyFactory).getRoyalty(baseToken);
        feeRoyalty = 0;
        uint256 feeBuyBack = 0;

        if (royalty != address(0)) {
            feeRoyalty = fee.div(2);
            TransferHelper.safeTransfer(bgbToken, royaltyFactory, feeRoyalty);
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee(baseToken, feeRoyalty);
        }

        leftFee = leftFee.sub(feeRoyalty);
        feeBuyBack = leftFee.div(2);
        leftFee = leftFee.sub(feeBuyBack);

        for (uint256 i = 0; i < 5; i++) {
            address buyBackToken = UniswapV2FactoryUpgradeable(factory).buyBackTokens(i);
            uint16 buyBackPct = UniswapV2FactoryUpgradeable(factory).buyBackPcts(i);
            if (buyBackToken == address(0) || buyBackPct == 0) {
                continue;
            }
            uint256 buyBackAmount = feeBuyBack.mul(buyBackPct).div(10000);
            if (buyBackAmount == 0) continue;
            if (buyBackToken == mbToken) {
                address[] memory feePath2 = new address[](2);
                feePath2[0] = bgbToken;
                feePath2[1] = mbToken;
                _swapInternal2FromThis(buyBackAmount, 0, feePath2, IUniswapV2Factory(factory).feeReceiver());
            } else {
                address[] memory feePath3 = new address[](3);
                feePath3[0] = bgbToken;
                feePath3[1] = mbToken;
                feePath3[2] = buyBackToken;
                _swapInternal2FromThis(buyBackAmount, 0, feePath3, IUniswapV2Factory(factory).feeReceiver());
            }
        }

        address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
        if (feeRecipient != address(0) && leftFee > 0) {
            TransferHelper.safeTransfer(bgbToken, feeRecipient, leftFee);
        }
    }

    function _processMbInputV2(uint256 fee, address[] memory path)
        internal
        virtual
        returns (uint256 feeRoyalty, uint256 leftFee)
    {
        if (fee == 0) return (0, 0);
        address mbToken = IUniswapV2Factory(factory).MB();
        address baseToken = path[path.length - 1];

        address[] memory feePath = new address[](2);
        leftFee = fee;

        // Royalty handling
        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        address royalty = IRoyaltyFactory(royaltyFactory).getRoyalty(baseToken);
        feeRoyalty = 0;
        uint256 feeBuyBack = 0;
        if (royalty != address(0)) {
            feeRoyalty = fee.div(2);
            TransferHelper.safeTransferFrom(mbToken, msg.sender, royaltyFactory, feeRoyalty);
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee(baseToken, feeRoyalty);
        }

        leftFee = leftFee.sub(feeRoyalty);
        // feeBuyBack = leftFee.div(2);
        feeBuyBack = leftFee.div(1);
        leftFee = leftFee.sub(feeBuyBack);

        // Buyback via MB -> buyBackToken (2-hop path). If buyBackToken is MB, transfer directly.
        for (uint256 i = 0; i < 5; i++) {
            address buyBackToken = UniswapV2FactoryUpgradeable(factory).buyBackTokens(i);
            uint16 buyBackPct = UniswapV2FactoryUpgradeable(factory).buyBackPcts(i);
            if (buyBackToken == address(0) || buyBackPct == 0) continue;
            uint256 buyBackAmount = feeBuyBack.mul(buyBackPct).div(10000);
            if (buyBackAmount == 0) continue;
            if (buyBackToken == mbToken) {
                // No swap needed, send MB directly to fee receiver from sender
                address feeRcpt = IUniswapV2Factory(factory).feeReceiver();
                if (feeRcpt != address(0)) {
                    TransferHelper.safeTransferFrom(mbToken, msg.sender, feeRcpt, buyBackAmount);
                }
            } else {
                feePath[0] = mbToken;
                feePath[1] = buyBackToken;
                // _swapInternal2(buyBackAmount, 0, feePath, IUniswapV2Factory(factory).feeReceiver());
                _swapInternal2(buyBackAmount, 0, feePath, 0x000000000000000000000000000000000000dEaD);
            }
        }

        // Remaining fee to fee receiver in MB
        address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
        if (feeRecipient != address(0) && leftFee > 0) {
            TransferHelper.safeTransferFrom(mbToken, msg.sender, feeRecipient, leftFee);
        }
    }

    function _processMbOutputV2(uint256 fee, address[] memory path)
        internal
        virtual
        returns (uint256 feeRoyalty, uint256 leftFee)
    {
        if (fee == 0) return (0, 0);
        address mbToken = IUniswapV2Factory(factory).MB();
        require(path.length >= 1, "Fee: INVALID_PATH");
        address baseToken = path[0];

        address[] memory feePath = new address[](2);
        leftFee = fee;

        // Royalty handling
        address royaltyFactory = IUniswapV2Factory(factory).royaltyFactory();
        address royalty = IRoyaltyFactory(royaltyFactory).getRoyalty(baseToken);
        feeRoyalty = 0;
        uint256 feeBuyBack = 0;
        if (royalty != address(0)) {
            feeRoyalty = fee.div(2);
            TransferHelper.safeTransfer(mbToken, royaltyFactory, feeRoyalty);
            IRoyaltyFactory(royaltyFactory).addRoyaltyFee(baseToken, feeRoyalty);
        }

        leftFee = leftFee.sub(feeRoyalty);
        // feeBuyBack = leftFee.div(2);
        feeBuyBack = leftFee.div(1);
        leftFee = leftFee.sub(feeBuyBack);

        // Buyback via MB -> buyBackToken (2-hop path), router holds MB. If buyBackToken is MB, transfer directly.
        for (uint256 i = 0; i < 5; i++) {
            address buyBackToken = UniswapV2FactoryUpgradeable(factory).buyBackTokens(i);
            uint16 buyBackPct = UniswapV2FactoryUpgradeable(factory).buyBackPcts(i);
            if (buyBackToken == address(0) || buyBackPct == 0) continue;
            uint256 buyBackAmount = feeBuyBack.mul(buyBackPct).div(10000);
            if (buyBackAmount == 0) continue;
            if (buyBackToken == mbToken) {
                // No swap needed, router holds MB
                address feeRcpt = IUniswapV2Factory(factory).feeReceiver();
                if (feeRcpt != address(0)) {
                    TransferHelper.safeTransfer(mbToken, feeRcpt, buyBackAmount);
                }
            } else {
                feePath[0] = mbToken;
                feePath[1] = buyBackToken;
                // _swapInternal2FromThis(buyBackAmount, 0, feePath, IUniswapV2Factory(factory).feeReceiver());
                _swapInternal2FromThis(buyBackAmount, 0, feePath, 0x000000000000000000000000000000000000dEaD);
            }
        }

        // Remaining fee to fee receiver in MB
        address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
        if (feeRecipient != address(0) && leftFee > 0) {
            TransferHelper.safeTransfer(mbToken, feeRecipient, leftFee);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        // Ensure one of the tokens in the swap is BGB token
        address bgbToken = IUniswapV2Factory(factory).BGB();
        address mbToken = IUniswapV2Factory(factory).MB();
        require(
            path[0] == bgbToken || path[path.length - 1] == bgbToken || path[0] == mbToken
                || path[path.length - 1] == mbToken,
            "TENETSWAPV2Router: MUST_INCLUDE_BGB_MB_TOKEN"
        );

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

            // Transfer fee to royalty/buyback/receiver internally
            uint256 feeRoyalty = 0;
            uint256 leftFee = 0;
            if (fee > 0) {
                // (feeRoyalty, leftFee) = _processBgbInputV2(fee, path);
                address feeRecipient = IUniswapV2Factory(factory).feeReceiver();
                if (feeRecipient != address(0)) {
                    TransferHelper.safeTransferFrom(bgbToken, msg.sender, feeRecipient, fee);
                }
            }

            // Emit swap event
            address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
            _emitSwapEvent2(
                msg.sender,
                path[0],
                path[path.length - 1],
                bgbToken,
                actualAmountIn,
                amounts[amounts.length - 1],
                fee,
                feeRoyalty,
                leftFee,
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

            // Distribute fee internally (router holds BGB) with royalty + buyback
            uint256 feeRoyalty = 0;
            uint256 leftFee = 0;
            if (fee > 0) {
                // (feeRoyalty, leftFee) = _processBgbOutputV2(fee, path);
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
            _emitSwapEvent2(
                msg.sender,
                path[0],
                path[path.length - 1],
                bgbToken,
                amountIn,
                actualBgbToUser,
                fee,
                feeRoyalty,
                leftFee,
                pair
            );

            return amounts;
        } else if (path[0] == mbToken) {
            // MB as input - collect fee from input
            uint256 fee = amountIn.mul(FeeHandler.FEE_NUMERATOR).div(FeeHandler.FEE_DENOMINATOR);
            uint256 actualAmountIn = amountIn.sub(fee);

            // Execute swap with actual amount after fee
            amounts = UniswapV2Library.getAmountsOut(factory, actualAmountIn, path);
            require(amounts[amounts.length - 1] >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), actualAmountIn
            );
            _swap(amounts, path, to);

            // Transfer fee to fee recipient (MB input branch)
            uint256 feeRoyalty = 0;
            uint256 leftFee = 0;
            if (fee > 0) {
                (feeRoyalty, leftFee) = _processMbInputV2(fee, path);
            }

            // Emit swap event
            address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
            _emitSwapEvent2(
                msg.sender,
                path[0],
                path[path.length - 1],
                mbToken,
                actualAmountIn,
                amounts[amounts.length - 1],
                fee,
                feeRoyalty,
                leftFee,
                pair
            );

            return amounts;
        } else if (path[path.length - 1] == mbToken) {
            // MB as output - execute swap first, then collect fee from output
            amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

            // Calculate expected output after fee
            uint256 expectedMbOutput = amounts[amounts.length - 1];
            uint256 fee = expectedMbOutput.mul(FeeHandler.FEE_NUMERATOR).div(FeeHandler.FEE_DENOMINATOR);
            uint256 actualMbToUser = expectedMbOutput.sub(fee);

            require(actualMbToUser >= amountOutMin, "TENETSWAPV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
            );
            _swap(amounts, path, address(this));

            // Transfer fee to fee recipient (MB output branch)
            uint256 feeRoyalty = 0;
            uint256 leftFee = 0;
            if (fee > 0) {
                (feeRoyalty, leftFee) = _processMbOutputV2(fee, path);
            }

            // Transfer actual MB to user
            TransferHelper.safeTransfer(mbToken, to, actualMbToUser);

            // Update amounts array to reflect actual user output
            amounts[amounts.length - 1] = actualMbToUser;

            // Emit swap event
            address pair = UniswapV2Library.pairFor(factory, path[0], path[1]);
            _emitSwapEvent2(
                msg.sender,
                path[0],
                path[path.length - 1],
                mbToken,
                amountIn,
                actualMbToUser,
                fee,
                feeRoyalty,
                leftFee,
                pair
            );

            return amounts;
        }
    }
}

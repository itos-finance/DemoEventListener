// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../lib/balancer-v2-monorepo/pkg/interfaces/contracts/vault/IVault.sol";
import "../lib/balancer-v2-monorepo/pkg/interfaces/contracts/vault/IFlashLoanRecipient.sol";
import { PositionManagerFacet } from "../lib/itos-position-manager/src/facets/PositionManagerFacet.sol";
import { MockERC20 } from "../lib/itos-position-manager/test/mocks/MockERC20.sol";
import {console2 as console, Script} from "forge-std/Script.sol";

struct LiquidationParams {
    uint256 portfolioId;
    address resolver;
    uint256[] positionIds;
    bytes[] instructions;
}

contract Liquidator is IFlashLoanRecipient {
    IVault internal vault; //= "0xBA12222222228d8Ba445958a75a0704d566BF2C8";
    address internal pm_addr;
    LiquidationParams internal params;
    uint256 internal locked;

    /// @notice simple reentrancy guard
    modifier nonReentrant() {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    constructor(address _pm, address _balancer_addr) {
        pm_addr = _pm;
        vault = IVault(_balancer_addr);
        // init unlocked
        locked = 1;
    }

    function liquidate(
        IERC20[] memory flashLoanTokens,
        uint256[] memory flashLoanAmounts,
        bytes memory userFlashLoanData,
        uint256 portfolioId,
        address resolver,
        uint256[] calldata positionIds,
        bytes[] calldata instructions
    ) external nonReentrant{
        params = LiquidationParams({
            portfolioId: portfolioId,
            resolver: resolver,
            positionIds: positionIds,
            instructions: instructions
        });
        vault.flashLoan(this, flashLoanTokens, flashLoanAmounts, userFlashLoanData);
        delete params;
    }


    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault));
        PositionManagerFacet(pm_addr).liquidate(
            params.portfolioId,
            params.resolver,
            params.positionIds,
            params.instructions
        );
    }

    // liquidate without a flash loan
    function liquidateNoFlashLoan(
        uint256 portfolioId,
        address resolver,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] calldata positionIds,
        bytes[] calldata instructions
    ) external nonReentrant {
        console.log("in kliq");
        // approve resolver to spend the specified amount of token
        for (uint256 i = 0; i < tokens.length; i++){
            console.log("approving %d of %s", amounts[i], tokens[i]);
            MockERC20(tokens[i]).approve(resolver, amounts[i]);
        }
        console.log("calling liq on the pm: %s", pm_addr);
        PositionManagerFacet(pm_addr).liquidate(
            portfolioId,
            resolver,
            positionIds,
            instructions
        );
    }

}

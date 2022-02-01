// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRecycler.sol";
import "./interfaces/IRecyclerManager.sol";
import "./libraries/SafeTransfer.sol";

/// @title RecyclerManager
contract RecyclerManager is IRecyclerManager {
    using SafeTransfer for address;

    struct CallbackData {
        address token;
        address payer;
        address payee;
        uint256 amount;
    }

    /// @inheritdoc IRecyclerManager
    address public immutable token;
    /// @inheritdoc IRecyclerManager
    IRecycler public immutable recycler;

    constructor(address token_, IRecycler recycler_) {
        token = token_;
        recycler = recycler_;
    }

    /// @inheritdoc IRecyclerManager
    function mint(address to, uint256 amount) external {
        CallbackData memory data = CallbackData({
            token: token,
            payer: msg.sender,
            payee: address(recycler),
            amount: amount
        });

        recycler.mint(to, amount, abi.encode(data));
    }

    /// @inheritdoc IRecyclerManager
    function mintCallback(bytes memory data) external {
        require(msg.sender == address(recycler), "Unauthorized");
        CallbackData memory decoded = abi.decode(data, (CallbackData));
        decoded.token.safeTransferFrom(decoded.payer, decoded.payee, decoded.amount);
    }
}

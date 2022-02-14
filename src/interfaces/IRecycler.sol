// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "yield-utils-v2/token/IERC20.sol";
import "yield-utils-v2/token/IERC20Metadata.sol";
import "yield-utils-v2/token/IERC2612.sol";

import "./IRecyclerActions.sol";
import "./IRecyclerErrors.sol";
import "./IRecyclerEvents.sol";
import "./IRecyclerState.sol";
import "./IRecyclerStateDerived.sol";

interface IRecycler is
    IRecyclerEvents,
    IRecyclerErrors,
    IRecyclerState,
    IRecyclerStateDerived,
    IRecyclerActions,
    IERC20,
    IERC20Metadata,
    IERC2612
{}

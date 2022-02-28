// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "yield-utils-v2/token/IERC20.sol";
import { IERC20Metadata } from "yield-utils-v2/token/IERC20Metadata.sol";

import { IERC4626 } from "../IERC4626.sol";
import { IRecyclerStorageV1Actions } from "./IRecyclerStorageV1Actions.sol";
import { IRecyclerStorageV1State } from "./IRecyclerStorageV1State.sol";

interface IRecyclerStorageV1 is
    IERC20,
    IERC20Metadata,
    IERC4626,
    IRecyclerStorageV1Actions,
    IRecyclerStorageV1State
{}

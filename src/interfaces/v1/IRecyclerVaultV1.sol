// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IRecyclerVaultV1Actions } from "./IRecyclerVaultV1Actions.sol";
import { IRecyclerVaultV1StateDerived } from "./IRecyclerVaultV1StateDerived.sol";

interface IRecyclerVaultV1 is
    IRecyclerVaultV1Actions,
    IRecyclerVaultV1StateDerived
{}

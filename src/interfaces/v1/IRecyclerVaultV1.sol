// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IRecyclerStorageV1 } from "./IRecyclerStorageV1.sol";
import { IRecyclerVaultV1Actions } from "./IRecyclerVaultV1Actions.sol";
import { IRecyclerVaultV1Events } from "./IRecyclerVaultV1Events.sol";
import { IRecyclerVaultV1StateDerived } from "./IRecyclerVaultV1StateDerived.sol";

interface IRecyclerVaultV1 is
    IRecyclerStorageV1,
    IRecyclerVaultV1Actions,
    IRecyclerVaultV1Events,
    IRecyclerVaultV1StateDerived
{}

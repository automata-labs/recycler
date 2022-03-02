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
{
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function maxRequest(address account) external view returns (uint256 maxAssets);
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function previewRequest(uint256 assets) external view returns (uint256 shares);
    /// @dev Extension of EIP-4626 (not included in the formal specification).
    function request(uint256 assets, address from) external returns (uint256 shares);
}

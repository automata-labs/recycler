// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ICallback {
    function loadCallback(bytes calldata data) external;

    function mintCallback(bytes calldata data) external;

    function burnCallback(bytes calldata data) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract MangoRepoInterface {
    function repoInterfaceVersion() external pure virtual returns (uint version);

    function refCount() external view virtual returns (uint count);
    function refName(uint index) external view virtual returns (string memory ref);
    function getRef(string memory ref) external view virtual returns (string memory hash);
    function setRef(string memory ref, string memory hash) external virtual;
    function deleteRef(string memory ref) external virtual;

    function snapshotCount() external view virtual returns (uint count);
    function getSnapshot(uint index) external view virtual returns (string memory hash);
    function addSnapshot(string memory hash) external virtual;

    function isObsolete() external view virtual returns (bool);
}

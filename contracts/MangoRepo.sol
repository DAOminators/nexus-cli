// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "github.com/axic/mango/MangoRepoInterface.sol";

contract MangoRepo is MangoRepoInterface {
    bool obsolete;
    mapping(address => bool) admins;
    mapping(address => bool) committers;
    string[] refKeys;
    mapping(string => string) refs;
    string[] snapshots;

    modifier committerOnly {
        require(committers[msg.sender], "Committer only");
        _;
    }

    modifier adminOnly {
        require(admins[msg.sender], "Admin only");
        _;
    }

    constructor() {
        admins[msg.sender] = true;
        committers[msg.sender] = true;
    }

    function repoInterfaceVersion() external pure override returns (uint version) {
        version = 1;
    }

    function refCount() external view override returns (uint) {
        return refKeys.length;
    }

    function refName(uint index) external view override returns (string memory ref) {
        ref = refKeys[index];
    }

    function getRef(string memory ref) external view override returns (string memory hash) {
        hash = refs[ref];
    }

    function __findRef(string memory ref) private view returns (int) {
        for (uint i = 0; i < refKeys.length; i++)
            if (keccak256(abi.encodePacked(refKeys[i])) == keccak256(abi.encodePacked(ref)))
                return int(i);
        return -1;
    }

    function setRef(string memory ref, string memory hash) external override committerOnly {
        if (__findRef(ref) == -1)
            refKeys.push(ref);
        refs[ref] = hash;
    }

    function deleteRef(string memory ref) external override committerOnly {
        int pos = __findRef(ref);
        if (pos != -1) {
            refKeys[uint(pos)] = "";
        }
        refs[ref] = "";
    }

    function snapshotCount() external view override returns (uint) {
        return snapshots.length;
    }

    function getSnapshot(uint index) external view override returns (string memory) {
        return snapshots[index];
    }

    function addSnapshot(string memory hash) external override committerOnly {
        snapshots.push(hash);
    }

    function setObsolete() external adminOnly {
        obsolete = true;
    }

    function isObsolete() external view override returns (bool) {
        return obsolete;
    }

    function authorize(address addr, bool admin) external adminOnly {
        committers[addr] = true;
        if (admin) {
            admins[addr] = true;
        }
    }

    function deauthorize(address addr, bool admin) external adminOnly {
        if (admin) {
            admins[addr] = false;
        } else {
            committers[addr] = false;
        }
    }
}

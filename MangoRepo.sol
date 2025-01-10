// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "MangoRepoInterface.sol";

contract MangoRepo is MangoRepoInterface {
    address owner;

    string[] refKeys;
    mapping(string => string) refs;
    string[] snapshots;

    modifier owneronly {
        require(msg.sender == owner, "Owner only");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function repoInterfaceVersion() external pure override returns (uint) {
        return 1;
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
        for (uint i = 0; i < refKeys.length; i++) {
            if (keccak256(abi.encodePacked(refKeys[i])) == keccak256(abi.encodePacked(ref))) {
                return int(i);
            }
        }
        return -1;
    }

    function setRef(string memory ref, string memory hash) external override owneronly {
        if (__findRef(ref) == -1) {
            refKeys.push(ref);
        }
        refs[ref] = hash;
    }

    function deleteRef(string memory ref) external override owneronly {
        int pos = __findRef(ref);
        if (pos != -1) {
            // FIXME: shrink the array?
            refKeys[uint(pos)] = "";
        }
        // FIXME: null? string(0)?
        refs[ref] = "";
    }

    function strEqual(string memory a, string memory b) private pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function snapshotCount() external view override returns (uint) {
        return snapshots.length;
    }

    function getSnapshot(uint index) external view override returns (string memory) {
        return snapshots[index];
    }

    function addSnapshot(string memory hash) external override owneronly {
        snapshots.push(hash);
    }

    function isObsolete() external pure override returns (bool) {
        return false;
    }
}

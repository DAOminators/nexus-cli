#!/usr/bin/env python3

import sys
import os
import argparse
from web3 import Web3
import eth_utils
import ipfshttpclient
import rlp


# Git remote helper protocol commands
def abort(msg=None):
    print(msg or "Error occurred", file=sys.stderr)
    sys.exit(1)


def capabilities():
    print("connect")
    print("push")
    print("fetch")
    print("\n")
    sys.stdout.flush()


def connect(service, repo, remote_name):
    if service == "git-upload-pack":
        # Handle fetch/pull
        fetch(repo)
    elif service == "git-receive-pack":
        # Handle push
        push(repo, remote_name)
    else:
        abort(f"Unknown service: {service}")


def fetch(repo):
    """Fetch all refs from the remote repository."""
    print("Fetching refs...")
    for ref in repo.refs():
        print(f"ref {ref['name']} {ref['hash']}")
    print("\n")
    sys.stdout.flush()


def push(repo, remote_name):
    """Push refs to the remote repository."""
    print("Pushing refs...")
    while True:
        line = sys.stdin.readline().strip()
        if not line:
            break

        # Parse the ref update line: <old-ref> <new-ref> <ref-name>
        old_ref, new_ref, ref_name = line.split()
        if new_ref == "0000000000000000000000000000000000000000":
            # Delete the ref
            repo.contract_set_ref(ref_name, "")
        else:
            # Update the ref
            repo.contract_set_ref(ref_name, new_ref)
    print("\n")
    sys.stdout.flush()


class Repo:
    def __init__(self, address, user=None):
        self.web3 = Web3(
            Web3.HTTPProvider(os.getenv("ETHEREUM_RPC_URL", "http://localhost:8545"))
        )
        self.user = user or self.web3.eth.coinbase
        self.repo_contract = self.web3.eth.contract(address=address, abi=repo_abi)

        self._object_map = {}

    def git_hash(self, obj_type, data):
        hasher = eth_utils.crypto.keccak()
        hasher.update(f"{obj_type} {len(data)}\0".encode())
        hasher.update(data)
        return hasher.hexdigest()

    def ipfs_put(self, buf):
        with ipfshttpclient.connect() as client:
            result = client.object.put(buf)
            return result["Hash"]

    def ipfs_get(self, key):
        with ipfshttpclient.connect() as client:
            result = client.object.get(key)
            return result["Data"]

    def _load_object_map(self):
        snapshots = self.snapshot_get_all()
        for item in snapshots:
            data = self.ipfs_get(item)
            self._object_map.update(snapshot.parse(data))

    def _ensure_object_map(self):
        if not self._object_map:
            self._load_object_map()

    def snapshot_add(self, hash_val):
        self.repo_contract.functions.addSnapshot(hash_val).transact({"from": self.user})

    def snapshot_get_all(self):
        count = self.repo_contract.functions.snapshotCount().call()
        snapshots = [
            self.repo_contract.functions.getSnapshot(i).call() for i in range(count)
        ]
        return snapshots

    def contract_get_ref(self, ref):
        return self.repo_contract.functions.getRef(ref).call()

    def contract_set_ref(self, ref, hash_val):
        self.repo_contract.functions.setRef(ref, hash_val).transact({"from": self.user})

    def contract_all_refs(self):
        refcount = self.repo_contract.functions.refCount().call()
        refs = {}
        for i in range(refcount):
            key = self.repo_contract.functions.refName(i).call()
            refs[key] = self.repo_contract.functions.getRef(key).call()
        return refs

    def refs(self, prefix=""):
        self._ensure_object_map()
        refs = self.contract_all_refs()
        for ref_name, ref_hash in refs.items():
            yield {"name": ref_name, "hash": ref_hash}

    def symrefs(self):
        yield {"name": "HEAD", "ref": "refs/heads/master"}

    def has_object(self, hash_val):
        self._ensure_object_map()
        return hash_val in self._object_map

    def get_object(self, hash_val):
        self._ensure_object_map()
        if hash_val not in self._object_map:
            raise ValueError(f"Object not present with key {hash_val}")
        data = self.ipfs_get(self._object_map[hash_val])
        res = rlp.decode(data)
        return {"type": res[0].decode(), "length": int(res[1]), "read": res[2]}

    def update(self, read_ref_updates=None, read_objects=None):
        if read_objects:
            for object_data in read_objects():
                buf = b"".join(object_data["read"])
                hash_val = self.git_hash(object_data["type"], buf)
                data = rlp.encode(
                    [
                        object_data["type"].encode(),
                        str(object_data["length"]).encode(),
                        buf,
                    ]
                )
                ipfs_hash = self.ipfs_put(data)
                self._object_map[hash_val] = ipfs_hash

            snapshot_data = snapshot.create(self._object_map)
            ipfs_hash = self.ipfs_put(snapshot_data)
            self.snapshot_add(ipfs_hash)

        if read_ref_updates:
            for update in read_ref_updates():
                ref = self.contract_get_ref(update["name"])
                if update["old"] != ref:
                    raise ValueError(
                        f'Ref update old value is incorrect. Ref: {update["name"]}, old in update: {update["old"]}, old in repo: {ref}'
                    )
                if update["new"]:
                    self.contract_set_ref(update["name"], update["new"])
                else:
                    self.repo_contract.functions.deleteRef(update["name"]).transact(
                        {"from": self.user}
                    )


def main():
    parser = argparse.ArgumentParser(
        description="Git Remote Helper for Smart Contract and IPFS Backend"
    )
    parser.add_argument(
        "command", choices=["clone", "push", "pull", "sync"], help="Command to execute"
    )
    parser.add_argument(
        "remote", help="Remote repository address (e.g., myhelper::0xYourRepoAddress)"
    )
    parser.add_argument(
        "--user", help="Ethereum account address to use for transactions"
    )
    args = parser.parse_args()

    # Initialize the Repo instance
    repo_address = args.remote.replace("myhelper::", "")
    repo = Repo(repo_address, user=args.user)

    if args.command == "clone":
        print(f"Cloning repository from {repo_address}...")
        for ref in repo.refs():
            print(f"ref {ref['name']} {ref['hash']}")
    elif args.command == "push":
        print(f"Pushing to repository at {repo_address}...")
        push(repo, args.remote)
    elif args.command == "pull":
        print(f"Pulling from repository at {repo_address}...")
        fetch(repo)
    elif args.command == "sync":
        print(f"Syncing repository at {repo_address}...")
        repo.update()
    else:
        abort(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()

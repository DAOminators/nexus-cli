// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract aamRepo {
    bool obsolete;
    mapping(address => bool) committers;
    uint8 numCommitters;
    
    enum ProposalType { Auth, Deauth }
    
    struct Proposal {
        address concerning;
        ProposalType proposalType;
        uint8 voteCount;
        bool executed;
        mapping(address => bool) hasVoted;
    }
    
    Proposal[] public proposals;
    
    string[] refKeys;
    mapping(string => string) refs;
    string[] snapshots;
    
    event ProposalCreated(uint256 proposalId, address concerning, ProposalType proposalType);
    event ProposalExecuted(uint256 proposalId, address concerning, ProposalType proposalType);
    event Voted(uint256 proposalId, address voter);
    event VoteRemoved(uint256 proposalId, address voter);
    
    modifier committerOnly {
        require(committers[msg.sender], "Committer only");
        _;
    }
    
    constructor() {
        committers[msg.sender] = true;
        numCommitters = 1;
    }
    
    // Voting System Functions
    function createProposal(address concerning, ProposalType proposalType) external committerOnly {
        require(
            (proposalType == ProposalType.Auth && !committers[concerning]) ||
            (proposalType == ProposalType.Deauth && committers[concerning]),
            "Invalid proposal"
        );
        
        uint256 newProposalId = proposals.length;
        proposals.push();
        Proposal storage newProposal = proposals[newProposalId];
        
        newProposal.concerning = concerning;
        newProposal.proposalType = proposalType;
        newProposal.voteCount = 0;
        newProposal.executed = false;
        
        emit ProposalCreated(newProposalId, concerning, proposalType);
    }

    function vote(uint256 proposalId) external committerOnly {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.hasVoted[msg.sender], "Already voted. Use removeVote to change");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount++;
        
        emit Voted(proposalId, msg.sender);
        
        // Check if proposal can be executed
        if (proposal.voteCount > numCommitters / 2) {
            executeProposal(proposalId);
        }
    }

    function removeVote(uint256 proposalId) external committerOnly {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(!proposal.executed, "Proposal already executed");
        require(proposal.hasVoted[msg.sender], "Haven't voted yet");
        
        proposal.hasVoted[msg.sender] = false;
        proposal.voteCount--;
        
        emit VoteRemoved(proposalId, msg.sender);
    }

    function getVoteCount(uint256 proposalId) external view returns (uint8) {
        require(proposalId < proposals.length, "Invalid proposal ID");
        return proposals[proposalId].voteCount;
    }
    
    function executeProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        
        if (proposal.proposalType == ProposalType.Auth || !committers[proposal.concerning]) {
            committers[proposal.concerning] = true;
            numCommitters++;
        } else if ((proposal.proposalType == ProposalType.Deauth || committers[proposal.concerning])) {
            committers[proposal.concerning] = false;
            numCommitters--;
        }
        else {
            require(proposal.executed, "Proposal Invalid!");
        }
        
        proposal.executed = true;
        emit ProposalExecuted(proposalId, proposal.concerning, proposal.proposalType);
    }
    
    function getProposal(uint256 proposalId) external view returns (
        address concerning,
        ProposalType proposalType,
        uint8 voteCount,
        bool executed
    ) {
        require(proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.concerning,
            proposal.proposalType,
            proposal.voteCount,
            proposal.executed
        );
    }
    
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        require(proposalId < proposals.length, "Invalid proposal ID");
        return proposals[proposalId].hasVoted[voter];
    }
    
    // Existing functions
    function repoInterfaceVersion() external pure returns (uint8 version) {
        version = 1;
    }
    
    function refCount() external view returns (uint) {
        return refKeys.length;
    }
    
    function refName(uint index) external view returns (string memory ref) {
        ref = refKeys[index];
    }
    
    function getRef(string memory ref) external view returns (string memory hash) {
        hash = refs[ref];
    }
    
    function __findRef(string memory ref) private view returns (int) {
        for (uint i = 0; i < refKeys.length; i++)
            if (keccak256(abi.encodePacked(refKeys[i])) == keccak256(abi.encodePacked(ref)))
                return int(i);
        return -1;
    }
    
    function setRef(string memory ref, string memory hash) external committerOnly {
        if (__findRef(ref) == -1)
            refKeys.push(ref);
        refs[ref] = hash;
    }
    
    function deleteRef(string memory ref) external committerOnly {
        int pos = __findRef(ref);
        if (pos != -1) {
            refKeys[uint(pos)] = "";
        }
        refs[ref] = "";
    }
    
    function snapshotCount() external view returns (uint) {
        return snapshots.length;
    }
    
    function getSnapshot(uint index) external view returns (string memory) {
        return snapshots[index];
    }
    
    function addSnapshot(string memory hash) external committerOnly {
        snapshots.push(hash);
    }
    
    function setObsolete() external committerOnly {
        obsolete = true;
    }
    
    function isObsolete() external view returns (bool) {
        return obsolete;
    }
    
    function hasAuthority(address addr) external view returns (bool) {
        return committers[addr];
    }
}
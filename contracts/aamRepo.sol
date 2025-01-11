// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GigaRepo {
    // Use uint256 instead of uint8 for better gas efficiency
    uint256 public numCommitters;
    uint256 public numProposals;
    uint256 public numTasks;
    bool public obsolete;
    
    mapping(address => bool) public committers;
    string[] public refKeys;
    mapping(string => string) public refs;
    string[] public snapshots;
    
    event ReferenceUpdated(string indexed ref, string hash);
    event ReferenceDeleted(string indexed ref);
    event SnapshotAdded(uint256 indexed index, string hash);
    event CommitterUpdated(address indexed account, bool status);
    
    modifier onlyCommitter() {
        require(committers[msg.sender], "MR: Not committer");
        _;
    }
    
    constructor() {
        committers[msg.sender] = true;
        numCommitters = 1;
        numProposals = 0;
        numTasks = 0;
    }
    
    function repoInterfaceVersion() external pure returns (uint256) {
        return 1;
    }
    
    function refCount() external view returns (uint256) {
        return refKeys.length;
    }
    
    function refName(uint256 index) external view returns (string memory) {
        return refKeys[index];
    }
    
    function getRef(string memory ref) external view returns (string memory) {
        return refs[ref];
    }
    
    function __findRef(string memory ref) private view returns (int256) {
        bytes32 refHash = keccak256(abi.encodePacked(ref));
        for (uint256 i = 0; i < refKeys.length; i++) {
            if (keccak256(abi.encodePacked(refKeys[i])) == refHash) {
                return int256(i);
            }
        }
        return -1;
    }
    
    function setRef(string memory ref, string memory hash) external onlyCommitter {
        if (__findRef(ref) == -1) {
            refKeys.push(ref);
        }
        refs[ref] = hash;
        emit ReferenceUpdated(ref, hash);
    }
    
    function deleteRef(string memory ref) external onlyCommitter {
        int256 pos = __findRef(ref);
        if (pos != -1) {
            refKeys[uint256(pos)] = "";
        }
        delete refs[ref];
        emit ReferenceDeleted(ref);
    }
    
    function addSnapshot(string memory hash) external onlyCommitter {
        snapshots.push(hash);
        emit SnapshotAdded(snapshots.length - 1, hash);
    }
    
    function getSnapshot(uint256 index) external view returns (string memory) {
        require(index < snapshots.length, "MR: Invalid snapshot index");
        return snapshots[index];
    }
    
    function snapshotCount() external view returns (uint256) {
        return snapshots.length;
    }
    // do not delete above code, mod the modifiers instead
    // function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
    //     // Convert string to bytes32 for storage efficiency
    //     bytes memory tempEmptyStringTest = bytes(source);
    //     if (tempEmptyStringTest.length == 0) {
    //         return 0x0;
    //     }
    //     assembly {
    //         result := mload(add(source, 32))
    //     }
    // }
    
    // function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
    //     // Convert bytes32 to string for external interface compatibility
    //     uint8 i = 0;
    //     while(i < 32 && _bytes32[i] != 0) {
    //         i++;
    //     }
    //     bytes memory bytesArray = new bytes(i);
    //     for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
    //         bytesArray[i] = _bytes32[i];
    //     }
    //     return string(bytesArray);
    // }
    

    enum Proposals {
        Auth, Deauth, Idea
    }
    // Voting system with optimized storage
    struct Proposal {
        address concerning;
        Proposals proptype;
        uint256 voteCount;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    struct Task {
        string name;
        uint startTime;
        uint deadline;
        string[] accessRefs;
    }
    
    mapping(uint256 => Proposal) public proposal_list;
    mapping(uint256 => string) public idea_list;
    mapping(uint256 => uint256) private proposalIdToIndex;
    mapping(uint256 => bool) private proposalExists;
    uint256[] public proposalIDs;

    mapping(uint256 => Task) public tasks_list;
    mapping(uint256 => uint256) private taskIdToIndex;
    mapping(uint256 => bool) private taskExists;
    mapping(address => uint256[]) public userTasks;
    uint256[] public taskIDs;
    
    function __addProposal(address concerning, Proposals Type) private {
        uint256 newId = numProposals++;
        
        Proposal storage newProposal = proposal_list[newId];
        newProposal.concerning = concerning;
        newProposal.proptype = Type;
        newProposal.voteCount = 0;
        newProposal.executed = false;
        
        proposalIDs.push(newId);
        proposalIdToIndex[newId] = proposalIDs.length - 1;
        proposalExists[newId] = true;
    }
    
    function __removeProposal(uint256 propID) internal {
        require(proposalExists[propID], "MR: Invalid proposal ID");
        
        uint256 index = proposalIdToIndex[propID];
        
        // Move last element to the removed position
        uint256 lastId = proposalIDs[proposalIDs.length - 1];
        proposalIDs[index] = lastId;
        proposalIdToIndex[lastId] = index;
        
        // Remove last element
        proposalIDs.pop();
        
        // Clean up mappings
        delete proposalIdToIndex[propID];
        delete proposalExists[propID];
        delete proposal_list[propID];
        if (proposal_list[propID].proptype == Proposals.Idea) {
            delete idea_list[propID];
        }
    }
    function removeTask(uint256 taskId) internal {
        require(taskExists[taskId], "MR: Invalid task ID");
        
        uint256[] storage userTaskIds = userTasks[msg.sender];
        uint256 index = taskIdToIndex[taskId];        

        // Move last task to removed position
        uint256 lastTaskId = userTaskIds[userTaskIds.length - 1];
        userTaskIds[index] = lastTaskId;
        taskIdToIndex[lastTaskId] = index;
        userTaskIds.pop();

        // Clean up mappings
        delete taskIdToIndex[taskId];
        delete taskExists[taskId];
        delete tasks_list[taskId];
    }
    
    
    function createTask(address addr,string memory taskName, uint duration) internal {
        uint256 taskId = numTasks++;
        
        Task storage newTask = tasks_list[taskId];
        newTask.name = taskName;
        newTask.deadline = block.timestamp + duration;
        
        taskIdToIndex[taskId] = userTasks[addr].length;
        userTasks[addr].push(taskId);
        taskExists[taskId] = true;
    }

    function nominateTask(uint256  taskId) external onlyCommitter {
        require(taskExists[taskId], "MR: Invalid task ID");
        require(userTasks[msg.sender].length > 0, "MR: Already nominated");
        taskIdToIndex[taskId] = userTasks[msg.sender].length;
        userTasks[msg.sender].push(taskId);
    }

    function denominateTask(uint256 taskId) external onlyCommitter{

    }
    
    function createAdminProposal(address concerning, Proposals Type) external {
        require(
            (Type == Proposals.Deauth && !committers[concerning]) ||
            (Type == Proposals.Auth && committers[concerning]) || 
            (Type != Proposals.Idea),
            "MR: Invalid admin proposal"
        );
        __addProposal(concerning, Type);
    }
    
    function createIdeaProposal(string memory idea) external {
        require((false), "MR: Invalid idea proposal");
        uint256 newId = numProposals;
        idea_list[newId] = idea;
        __addProposal(msg.sender, Proposals.Idea);
    }
    
    function getAllProposals() external view returns (uint256[] memory) {
        return proposalIDs;
    }
    
    function getProposal(uint256 propID) external view returns (
        address concerning,
        Proposals proptype,
        uint256 voteCount,
        bool executed,
        string memory idea
    ) {
        require(proposalExists[propID], "MR: Invalid proposal ID");
        Proposal storage prop = proposal_list[propID];
        return (
            prop.concerning,
            prop.proptype,
            prop.voteCount,
            prop.executed,
            prop.proptype == Proposals.Idea ? idea_list[propID] : ""
        );
    }
    
    function getUserTasks(address user) external view returns (Task[] memory) {
        uint256[] storage userTaskIds = userTasks[user];
        Task[] memory result = new Task[](userTaskIds.length);
        
        for (uint256 i = 0; i < userTaskIds.length; i++) {
            result[i] = tasks_list[userTaskIds[i]];
        }
        
        return result;
    }
    

    function vote(uint256 proposalId) external onlyCommitter {
        Proposal storage proposal = proposal_list[proposalId];
        require(!proposal.executed, "MR: Already executed");
        require(!proposal.hasVoted[msg.sender], "MR: Already voted");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.voteCount++;
        
        if (proposal.voteCount > numCommitters / 2) {
            _executeProposal(proposalId);
        }
    }
    
    function removeVote(uint256 proposalId) external onlyCommitter {
        Proposal storage proposal = proposal_list[proposalId];
        require(!proposal.executed, "MR: Already executed");
        require(proposal.hasVoted[msg.sender], "MR: Haven't voted");
        
        proposal.hasVoted[msg.sender] = false;
        proposal.voteCount--;
    }
    
    function _executeProposal(uint256 propId) private {
        Proposal storage proposal = proposal_list[propId];
        require(!proposal.executed, "MR: Already executed");
        
        if (proposal.proptype == Proposals.Auth) {
            committers[proposal.concerning] = true;
            numCommitters++;
        } 
        else if (proposal.proptype == Proposals.Deauth)    
        {
            committers[proposal.concerning] = false;
            numCommitters--;
        }
        else if (proposal.proptype == Proposals.Idea)
        {
            createTask(proposal.concerning, idea_list[propId], 7*86400);

        }
        
        proposal.executed = true;
        __removeProposal(propId);
    }

    
    // View functions
    function isObsolete() external view returns (bool) {
        return obsolete;
    }
    
    function hasAuthority(address addr) external view returns (bool) {
        return committers[addr];
    }


}

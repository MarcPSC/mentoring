pragma solidity ^0.8.0;

contract Lock {
    
    address public creator; 
    uint public endTime; 
    
    mapping(address => bool) public hasParticipated; 
    mapping(address => uint) public contributions; 
    
    uint public constant MINIMUM_CONTRIBUTION = 0.05 ether; 
    uint public constant MAXIMUM_CONTRIBUTION = 0.2 ether; 
    
    bool public isLocked; 
    
    modifier onlyCreator() {
        require(msg.sender == creator, "Only the creator can perform this action");
        _;
    }
    
    modifier onlyUnlocked() {
        require(!isLocked, "Contract is locked");
        _;
    }
    
    constructor() {
        creator = msg.sender;
        endTime = block.timestamp + 2 days; 
        isLocked = false;
    }
    
    function contribute() public payable onlyUnlocked {
        require(block.timestamp < endTime, "Crowdfunding has ended"); 
        require(msg.value >= MINIMUM_CONTRIBUTION && msg.value <= MAXIMUM_CONTRIBUTION, "Invalid contribution amount"); 
        require(!hasParticipated[msg.sender], "User has already participated"); 
        
        hasParticipated[msg.sender] = true;
        contributions[msg.sender] = msg.value;
    }
    
    function lock() public onlyCreator {
        isLocked = true; // Lock the contract
    }
    
    function unlock() public onlyCreator {
        isLocked = false; // Unlock the contract
    }
    
    function transfer() public onlyCreator onlyUnlocked {
        require(block.timestamp >= endTime, "Crowdfunding is still ongoing"); 
        
        uint balance = address(this).balance;
        require(balance > 0, "No funds available for transfer");
        
        bool success = payable(creator).send(balance); 
        require(success, "Transfer failed");
    }
}
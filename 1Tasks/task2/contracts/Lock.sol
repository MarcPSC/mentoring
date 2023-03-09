pragma solidity ^0.8.0;

contract Lock {
    mapping(address => uint256) public balances;
    address public owner;
    uint256 public totalBalance;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this action");
        _;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        totalBalance += msg.value;
    }

    function withdraw(uint256 amount) external payable {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        totalBalance -= amount;
        payable(msg.sender).transfer(amount);
    }

    function withdrawAll() external payable onlyOwner {
        require(totalBalance > 0, "No balance to withdraw");
        payable(owner).transfer(totalBalance);
        totalBalance = 0;
    }
}

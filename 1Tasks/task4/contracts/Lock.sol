pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Lock {
    
    enum Option { A, B, C, D }
    
    struct Voter {
        uint amount;
        Option option;
    }
    
    mapping(address => Voter) public voters;
    mapping (Option => uint) public optionNVotes;
    
    uint public votingPeriodEnd;
    Option public wOption;
    uint public winningAmmount;
    uint public totalAmount;
    
    constructor() {
        votingPeriodEnd = block.timestamp + 2 days;
        //wOption = Option.A;
        //totalAmount = 0;
        //winningAmmount = 0;
    }
    
    function vote(Option option) public payable {
        require(block.timestamp < votingPeriodEnd, "Voting period has ended.");
        require(msg.value > 0, "Amount cannot be zero.");
        
        Voter storage voter = voters[msg.sender];
        
        if (voter.amount == 0) {
            voter.option = option;
        } else {
            require(voter.option == option, "Cannot change vote.");
        }

        optionNVotes[option] += (msg.value / 1000000000000000000);

        if(optionNVotes[option] > winningAmmount) {
            wOption = option;
            winningAmmount = optionNVotes[option];
        }

        voter.amount += (msg.value / 1000000000000000000);
        totalAmount += msg.value;
    }
    
    function distributeBonus() public {
        require(block.timestamp >= votingPeriodEnd, "Voting period has not ended.");

        Voter storage voter = voters[msg.sender];
        
        if(voter.option == wOption) {
            uint voterShare = totalAmount * voter.amount / winningAmmount;
      
            payable(msg.sender).transfer(voterShare);
            voter.amount = 0;
        }
        
        // for (uint i = 0; i < optionVoters[wOption].length; i++) {
        //     Voter storage voter = voters[optionVoters[wOption][i]];
        //     uint voterShare = totalBonus * (voter.amount / winningAmmount);
        //     address payable addr = payable(optionVoters[wOption][i]);
        //     console.log(addr);
        //     addr.transfer(voterShare);
        //     voter.amount = 0;
        // }

        //Looking on the internet I saw it is a bad idea to make a loop sending all the coins. Am I wrong?
    }

    function optionVotes(Option option) public view returns ( uint ) {
        return optionNVotes[option];
    }
    
    function winningOption() public view returns ( Option option ) {
        return wOption;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AIPredictionMarket {

    struct Market {
        uint256 id;
        string question;
        string description;
        uint256 resolutionTimestamp;
        uint256 totalYes;
        uint256 totalNo;
        bool resolved;
        bool outcomeYes;
    }

    struct Bet {
        uint256 amount;
        bool betYes;
        bool paid;
    }

    uint256 public marketCounter;
    address public aiOperator;
    IERC20 public token;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Bet)) public bets;
    mapping(uint256 => address[]) public participants;

    modifier onlyAI() {
        require(msg.sender == aiOperator, "Only AI operator can call");
        _;
    }

    constructor(address _aiOperator, address _token) {
        aiOperator = _aiOperator;
        token = IERC20(_token);
    }

    function createMarket(
        string calldata question,
        string calldata description,
        uint256 resolutionTimestamp
    ) external onlyAI {
        require(resolutionTimestamp > block.timestamp, "Resolution must be in future");

        marketCounter++;
        markets[marketCounter] = Market({
            id: marketCounter,
            question: question,
            description: description,
            resolutionTimestamp: resolutionTimestamp,
            totalYes: 0,
            totalNo: 0,
            resolved: false,
            outcomeYes: false
        });
    }

    function placeBet(uint256 marketId, bool betYes, uint256 amount) external {
        Market storage market = markets[marketId];
        require(!market.resolved, "Market resolved");
        require(block.timestamp < market.resolutionTimestamp, "Market closed");
        require(amount > 0, "Must bet non-zero");
        require(bets[marketId][msg.sender].amount == 0, "You already placed bet");

        // transfer tokens from user to contract
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        if (betYes) {
            market.totalYes += amount;
        } else {
            market.totalNo += amount;
        }

        bets[marketId][msg.sender] = Bet({
            amount: amount,
            betYes: betYes,
            paid: false
        });

        participants[marketId].push(msg.sender);
    }

    function resolveMarket(uint256 marketId, bool outcomeYes) external onlyAI {
        Market storage market = markets[marketId];
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.resolutionTimestamp, "Too early to resolve");

        market.resolved = true;
        market.outcomeYes = outcomeYes;

        uint256 totalPool = market.totalYes + market.totalNo;
        uint256 winningPool = outcomeYes ? market.totalYes : market.totalNo;
        uint256 losingPool = outcomeYes ? market.totalNo : market.totalYes;

        if (winningPool == 0) {
            // refund AI operator if no one wins
            require(token.transfer(aiOperator, totalPool), "Refund failed");
            return;
        }

        // Calculate AI fee: 5% of losing pool
        uint256 aiFee = (losingPool * 5) / 100;
        uint256 distributableLosing = losingPool - aiFee;
        uint256 adjustedPool = winningPool + distributableLosing;

        // Pay AI fee
        require(token.transfer(aiOperator, aiFee), "AI fee payout failed");

        // payout winners
        for (uint i = 0; i < participants[marketId].length; i++) {
            address user = participants[marketId][i];
            Bet storage userBet = bets[marketId][user];

            if (!userBet.paid && userBet.betYes == outcomeYes) {
                uint256 payout = (userBet.amount * adjustedPool) / winningPool;
                userBet.paid = true;
                require(token.transfer(user, payout), "Payout failed");
            }
        }
    }

    // In case you ever want to update AI operator in future
    function setAiOperator(address newOperator) external onlyAI {
        aiOperator = newOperator;
    }
}

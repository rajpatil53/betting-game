//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// 0x5BE61BbbA8d244E0B77e30306Ac7F5Bfdc7E01eF
contract Casino {
    struct ProposedBet {
        address sideA;
        uint value;
        uint placedAt;
        bool accepted;
        uint randomA;
    } // struct ProposedBet

    struct AcceptedBet {
        address sideB;
        uint acceptedAt;
        uint commitmentB;
        uint randomB;
    } // struct AcceptedBet

    // Proposed bets, keyed by the commitment value
    mapping(uint => ProposedBet) public proposedBet;

    // Accepted bets, also keyed by commitment value
    mapping(uint => AcceptedBet) public acceptedBet;

    event BetProposed(uint indexed _commitment, uint value);

    event BetAccepted(uint indexed _commitment, address indexed _sideA);

    event BetSettled(
        uint indexed _commitment,
        address winner,
        address loser,
        uint value
    );

    // Called by sideA to start the process
    function proposeBet(uint _commitmentA) external payable {
        require(
            proposedBet[_commitmentA].value == 0,
            "there is already a bet on that commitment"
        );
        require(msg.value > 0, "you need to actually bet something");

        proposedBet[_commitmentA].sideA = msg.sender;
        proposedBet[_commitmentA].value = msg.value;
        proposedBet[_commitmentA].placedAt = block.timestamp;
        // accepted is false by default

        emit BetProposed(_commitmentA, msg.value);
    } // function proposeBet

    // Called by sideB to continue
    function acceptBet(uint _commitmentA, uint _commitmentB) external payable {
        require(
            !proposedBet[_commitmentA].accepted,
            "Bet has already been accepted"
        );
        require(
            proposedBet[_commitmentA].sideA != address(0),
            "Nobody made that bet"
        );
        require(
            msg.value == proposedBet[_commitmentA].value,
            "Need to bet the same amount as sideA"
        );

        acceptedBet[_commitmentA].sideB = msg.sender;
        acceptedBet[_commitmentA].acceptedAt = block.timestamp;
        acceptedBet[_commitmentA].commitmentB = _commitmentB;
        proposedBet[_commitmentA].accepted = true;

        emit BetAccepted(_commitmentA, proposedBet[_commitmentA].sideA);
    } // function acceptBet

    // Called by sideA to reveal their random value
    function revealProposer(uint _randomA) external {
        uint _commitmentA = uint256(keccak256(abi.encodePacked(_randomA)));

        require(
            proposedBet[_commitmentA].sideA == msg.sender,
            "Not a bet you placed or wrong value"
        );
        require(
            proposedBet[_commitmentA].accepted,
            "Bet has not been accepted yet"
        );

        if (acceptedBet[_commitmentA].randomB != 0) {
            revealResult(_commitmentA, _randomA);
        } else {
            proposedBet[_commitmentA].randomA = _randomA;
        }
    } // function reveal

    // Called by sideA to reveal their random value and conclude the bet
    function revealAcceptor(uint _commitmentA, uint _randomB) external {
        uint _commitmentB = uint256(keccak256(abi.encodePacked(_randomB)));

        require(
            acceptedBet[_commitmentA].sideB == msg.sender,
            "Not a bet you accepted."
        );
        require(
            proposedBet[_commitmentA].accepted,
            "Bet has not been accepted yet"
        );
        require(
            acceptedBet[_commitmentA].commitmentB == _commitmentB,
            "This is a wrong value"
        );

        if (proposedBet[_commitmentA].randomA != 0) {
            revealResult(_commitmentA, _randomB);
        } else {
            acceptedBet[_commitmentA].randomB = _randomB;
        }
    } // function reveal

    function revealResult(uint _commitmentA, uint _latestRandom) private {
        ProposedBet memory currentProposedBet = proposedBet[_commitmentA];
        AcceptedBet memory currentAcceptedBet = acceptedBet[_commitmentA];
        uint _previousRandom;
        if (currentProposedBet.randomA != 0) {
            _previousRandom = currentProposedBet.randomA;
        } else {
            _previousRandom = currentAcceptedBet.randomB;
        }
        uint _agreedRandom = _previousRandom ^ _latestRandom;
        address payable _sideA = payable(currentProposedBet.sideA);
        address payable _sideB = payable(currentAcceptedBet.sideB);
        uint _value = currentProposedBet.value;

        // Pay and emit an event
        if (_agreedRandom % 2 == 0) {
            // sideA wins
            _sideA.transfer(2 * _value);
            emit BetSettled(_commitmentA, _sideA, _sideB, _value);
        } else {
            // sideB wins
            _sideB.transfer(2 * _value);
            emit BetSettled(_commitmentA, _sideB, _sideA, _value);
        }

        // Cleanup
        delete proposedBet[_commitmentA];
        delete acceptedBet[_commitmentA];
    }
} // contract Casino

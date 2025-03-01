// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./piggyBank.sol";

contract PiggyFactory {
    event PiggyCreated(address indexed owner, address piggyAddress, uint256 duration, string savingPurpose);

    mapping(address => address[]) public userPiggies; // Track multiple PiggyBanks per user
    address[] public allPiggyBanks; // Store all deployed PiggyBanks

    function createPiggy(uint256 _duration, string memory _savingPurpose) external returns (address) {
        // Generate a unique salt based on sender address and a counter
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, block.timestamp, _savingPurpose));

        // Deploy Piggy using CREATE2
       MyPiggy piggy = new MyPiggy{salt: salt}(_duration, _savingPurpose, address(this));


        userPiggies[msg.sender].push(address(piggy)); // Store in user's piggy list
        allPiggyBanks.push(address(piggy)); // Store in global piggy list

        emit PiggyCreated(msg.sender, address(piggy), _duration, _savingPurpose);
        return address(piggy);
    }

    function getUserPiggies(address _user) external view returns (address[] memory) {
        return userPiggies[_user];
    }

    function getAllPiggyBanks() external view returns (address[] memory) {
        return allPiggyBanks;
    }

    function getPredictedAddress(address _user, uint256 _duration, string memory _savingPurpose) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_user, block.timestamp, _savingPurpose));
        bytes32 bytecodeHash = keccak256(abi.encodePacked(type(MyPiggy).creationCode, abi.encode(address(this), _duration, _savingPurpose)));

        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./piggyBank.sol";

contract PiggyFactory {
    event PiggyCreated(address indexed owner, address piggyAddress, uint256 duration, string savingPurpose);

    mapping(address => address[]) public userPiggies;
    address[] public allPiggyBanks;

    function createPiggy(uint256 _duration, string memory _savingPurpose) external returns (address) {
        // Generate a unique salt without using block.timestamp
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, _savingPurpose));

        // Deploy Piggy using CREATE2
        MyPiggy piggy = new MyPiggy{salt: salt}(_duration, _savingPurpose, address(this));

        userPiggies[msg.sender].push(address(piggy));
        allPiggyBanks.push(address(piggy));

        emit PiggyCreated(msg.sender, address(piggy), _duration, _savingPurpose);
        return address(piggy);
    }

    function getUserPiggies(address _user) external view returns (address[] memory) {
        return userPiggies[_user];
    }

    function getAllPiggyBanks() external view returns (address[] memory) {
        return allPiggyBanks;
    }

    function getPredictedAddress(address _user, uint256 _duration, string memory _savingPurpose) 
        external 
        view 
        returns (address) 
    {
        // Generate the same salt as used in createPiggy
        bytes32 salt = keccak256(abi.encodePacked(_user, _savingPurpose));
        
        // Calculate bytecode hash with constructor arguments in the correct order
        bytes32 bytecodeHash = keccak256(abi.encodePacked(
            type(MyPiggy).creationCode,
            abi.encode(_duration, _savingPurpose, address(this))
        ));

        return address(uint160(uint(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }
}
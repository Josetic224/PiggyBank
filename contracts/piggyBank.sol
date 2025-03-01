// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IERC20.sol";

// Error Library
library PiggyErrors {
    error InvalidAddress();
    error DepositsClosed();
    error InvalidTokenName();
    error DepositPeriodNotStarted();
    error DepositPeriodEnded();
    error WithdrawalNotAllowed();
    error NoFundsToWithdraw();
    error TransferFailed();
}

contract MyPiggy {
    using PiggyErrors for *;

    uint256 public startTime;
    uint256 public duration;
    string public savingPurpose;
    uint256 constant public BASISPOINT = 10000;
    uint256 constant public penaltyFee = 1500;
    bool public withdrawn;
    
    address immutable factoryAddress;

    mapping(string => address) public tokenNameToAddress;
    mapping(address => string) public addressToName;
    mapping(address => mapping(address => uint256)) public balances;
    mapping(address => uint256) public contractBalance;

    event Deposited(address indexed sender, address indexed token, uint256 amount);
    event WithdrawalSuccessful(address indexed recipient, uint256 amount);

    constructor(uint256 _duration, string memory _savingPurpose, address _factoryAddress) {
        if (msg.sender == address(0)) revert PiggyErrors.InvalidAddress();
        
        tokenNameToAddress["USDT"] = 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06;
        tokenNameToAddress["USDC"] = 0x583031D1113aD414F02576BD6afaBfb302140225;
        tokenNameToAddress["DAI"] = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

            addressToName[0x7169D38820dfd117C3FA1f22a697dBA58d90BA06] = "USDT";
        addressToName[0x583031D1113aD414F02576BD6afaBfb302140225] = "USDC";
        addressToName[0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c] = "DAI";

                    startTime = block.timestamp;
        duration = _duration;
        savingPurpose = _savingPurpose;
                factoryAddress = _factoryAddress;
    }

    modifier onlyAfterDuration() {
        if (block.timestamp <= startTime + duration) revert PiggyErrors.WithdrawalNotAllowed();
        _;
    }

    function deposit(uint256 _amount, string memory _tokenName) external {
        if (withdrawn) revert PiggyErrors.DepositsClosed();
        if (msg.sender == address(0)) revert PiggyErrors.InvalidAddress();
        if (_amount == 0) revert PiggyErrors.NoFundsToWithdraw();

                address tokenAddress = tokenNameToAddress[_tokenName];
        if (tokenAddress == address(0)) revert PiggyErrors.InvalidTokenName();
         if (block.timestamp < startTime) revert PiggyErrors.DepositPeriodNotStarted();
        if (block.timestamp > startTime + duration) revert PiggyErrors.DepositPeriodEnded();

        IERC20 token = IERC20(tokenAddress);
        if (!token.transferFrom(msg.sender, address(this), _amount)) revert PiggyErrors.TransferFailed();
    
        balances[msg.sender][tokenAddress] += _amount;
        contractBalance[tokenAddress] += _amount;
        emit Deposited(msg.sender, tokenAddress, _amount);
    }

    function withdraw() external onlyAfterDuration {
        if (msg.sender == address(0)) revert PiggyErrors.InvalidAddress();
        uint256 withdrawalAmount = balances[msg.sender][address(this)];
            if (withdrawalAmount == 0) revert PiggyErrors.NoFundsToWithdraw();

        IERC20 token = IERC20(address(this));
        if (!token.transfer(msg.sender, withdrawalAmount)) revert PiggyErrors.TransferFailed();

        balances[msg.sender][address(this)] -= withdrawalAmount;
        contractBalance[address(this)] -= withdrawalAmount;
        withdrawn = true;

        emit WithdrawalSuccessful(msg.sender, withdrawalAmount);
    }

    function emergencyWithdraw() external {
        if (msg.sender == address(0)) revert PiggyErrors.InvalidAddress();
        uint256 withdrawalAmount = balances[msg.sender][address(this)];
             if (withdrawalAmount == 0) revert PiggyErrors.NoFundsToWithdraw();

        uint256 penalty = (withdrawalAmount * penaltyFee) / BASISPOINT;
        uint256 finalAmount = withdrawalAmount - penalty;

        IERC20 token = IERC20(address(this));
        if (!token.transfer(factoryAddress, penalty)) revert PiggyErrors.TransferFailed();
        if (!token.transfer(msg.sender, finalAmount)) revert PiggyErrors.TransferFailed();

        balances[msg.sender][address(this)] -= withdrawalAmount;
            contractBalance[address(this)] -= withdrawalAmount;

        emit WithdrawalSuccessful(msg.sender, finalAmount);
    }

    function getPiggyBalance() external view returns (uint256) {
        return (contractBalance[address(this)] * penaltyFee) / BASISPOINT;
    }
}

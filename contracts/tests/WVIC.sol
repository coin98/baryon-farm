// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../interfaces/IWVIC.sol";

import "../libraries/VRC25Permit.sol";

/**
 * @title Wrapped Viction contract with VRC25Permit
 * @notice Wrapped Viction for gaslass operation
 */
contract WVIC is VRC25Permit, IWVIC {
    constructor() public
    VRC25("Wrapped Viction", "WVIC", 18, 0)
    EIP712("WVIC", "1") {}

    function _estimateFee(uint256) internal view override returns (uint256) {
        return minFee();
    }

    /**
     * @notice Deposit native token to receive equivalent wrapped VRC25 token
     * Amount of token received token equal `msg.value`
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice Deposit native token to receive equivalent wrapped VRC25 token
     * Amount of token received token equal `msg.value`
     */
    fallback() external payable {
        deposit();
    }

    /**
     * @notice Deposit native token to receive equivalent wrapped VRC25 token
     * Amount of token received token equal `msg.value`
     */
    function deposit() public payable override {
        uint256 fee = estimateFee(0);
        _mint(msg.sender, msg.value);
        _chargeFeeFrom(msg.sender, address(this), fee);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw native token by exchanging wrapped token
     * @param value Amount of native token to receive
     */
    function withdraw(uint256 value) public override {
        uint256 fee = estimateFee(0);
        _burn(msg.sender, value);
        _chargeFeeFrom(msg.sender, address(this), fee);
        msg.sender.transfer(value);
        emit Withdrawal(msg.sender, value);
    }

    /**
     * @notice Remove `amount` tokens owned by caller from circulation, call withdraw function.
     */
    function burn(uint256 amount) external override returns (bool) {
        withdraw(amount);
        return true;
    }
}

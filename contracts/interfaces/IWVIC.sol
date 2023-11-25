// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IWVIC {
  /**
   * @notice Emitted when `value` tokens are minted when user depsoit native token
   *
   * Note that `value` may be zero.
   */
  event Deposit(address indexed to, uint256 value);

  /**
   * @notice Emitted when `value` tokens are burned when user withdraw native token
   *
   * Note that `value` may be zero.
   */
  event Withdrawal(address indexed from, uint256 value);

  /**
   * @notice Deposit native token to receive equivalent wrapped VRC25 token
   * Amount of token received token equal `msg.value`
   */
  function deposit() payable external;

  /**
   * @notice Withdraw native token by exchanging wrapped token
   * @param value Amount of native token to receive
   */
  function withdraw(uint256 value) external;
}

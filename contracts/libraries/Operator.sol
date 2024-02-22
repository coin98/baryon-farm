// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import './Context.sol';

abstract contract Operator is Context {
    address private _operator;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial operator.
     */
    constructor() {
        address msgSender = _msgSender();
        _operator = msgSender;
        emit OperatorTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current operator.
     */
    function operator() public view virtual returns (address) {
        return _operator;
    }

    /**
     * @dev Throws if called by any account other than the operator.
     */
    modifier onlyOperator() {
        require(
            operator() == _msgSender(),
            "Ownable: Caller is not the operator"
        );
        _;
    }

    /**
     * @dev Leaves the contract without operator. It will not be possible to call
     * `onlyOperator` functions anymore. Can only be called by the current operator.
     *
     * NOTE: Renouncing operator will leave the contract without an operator,
     * thereby removing any functionality that is only available to the operator.
     */
    function renounceOperator() public virtual onlyOperator {
        emit OperatorTransferred(_operator, address(0));
        _operator = address(0);
    }

    /**
     * @dev Transfers operator of the contract to a new account (`newOperator`).
     * Can only be called by the current operator.
     */
    function transferOperator(address newOperator) public virtual onlyOperator {
        require(
            newOperator != address(0),
            "Ownable: New operator is the zero address"
        );
        emit OperatorTransferred(_operator, newOperator);
        _operator = newOperator;
    }
}
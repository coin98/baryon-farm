// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import './Ownable.sol';

/**
 * @dev Provide mechanism for Time Locking, Owner of contract can unlock this contract, after locking time
 * owner can execute special function and then contract will be lock again.
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract TimeLock is Ownable {
    uint256 private _lockTime;

    mapping(bytes4 => bool) _isUnlock;
    mapping(bytes4 => uint256) _unlockAts;

    event Unlock(bytes4 _functionSign, uint256 _timeUnlock);

    /**
     * @dev Initializes the contract setting the deployer as the initial lock time.
     */
    constructor(uint256 lockTime) {
        _lockTime = lockTime;
    }

    /**
     * @dev Returns contract is unlock.
     */
    function isUnlock(bytes4 _functionSign) public view virtual returns (bool) {
        return
            _isUnlock[_functionSign] &&
            (_unlockAts[_functionSign] + _lockTime) <= block.timestamp;
    }

    /**
     * @dev Throws if contract is lock, after execute function contract will be lock again.
     */
    modifier whenUnlock() {
        require(isUnlock(msg.sig), "LockSchedule: contract is locked");
        _;
        _isUnlock[msg.sig] = false;
    }

    /**
     * @dev Unlock contract, contract state Lock -> Pending -> Unlock -> Lock.
     */
    function unlock(bytes4 _functionSign) external onlyOwner {
        _isUnlock[_functionSign] = true;
        _unlockAts[_functionSign] = block.timestamp;

        emit Unlock(_functionSign, block.timestamp);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "./interfaces/IVRC25.sol";
import "./interfaces/IERC165.sol";

import "./libraries/Address.sol";
import "./libraries/SafeMath.sol";

/**
 * @title Base VRC25 implementation
 * @notice VRC25 implementation for opt-in to gas sponsor program. This replace Ownable from OpenZeppelin as well.
 */
abstract contract VRC25 is IVRC25, IERC165 {
    using Address for address;
    using SafeMath for uint256;

    // The order of _balances, _minFeem, _issuer must not be changed to pass validation of gas sponsor application
    mapping (address => uint256) private _balances;
    uint256 private _minFee;
    address private _owner;
    address private _newOwner;

    mapping (address => mapping (address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    // TimeLock variable
    uint256 private _lockTime;
    mapping(bytes4 => bool) _isUnlock;
    mapping(bytes4 => uint256) _unlockAts;


    // VRC25 events
    event FeeUpdated(uint256 fee);
    event OwnershipTransferredVRC25(address indexed previousOwner, address indexed newOwner);

    // TimeLock events
    event Unlock(bytes4 _functionSign, uint256 _timeUnlock);

    constructor(string memory name, string memory symbol, uint8 decimals_, uint256 lockTime) internal {
        _name = name;
        _symbol = symbol;
        _decimals = decimals_;
        _owner = msg.sender;
        _lockTime = lockTime;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() virtual {
        require(_owner == msg.sender, "VRC25: caller is not the owner");
        _;
    }

    /**
     * @notice Name of token
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Symbol of token
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Returns the amount of tokens in existence.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @notice Returns the amount of tokens owned by `account`.
     * @param owner The address to query the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    /**
     * @notice Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner,address spender) public view override returns (uint256){
        return _allowances[owner][spender];
    }

    // /**
    //  * @notice Owner of the token
    //  */
    // function owner() public view virtual returns (address) {
    //     return _owner;
    // }

    /**
     * @notice Owner of the token
     */
    function issuer() public view virtual override returns (address) {
        return _owner;
    }

    /**
     * @dev The amount fee that will be lost when transferring.
     */
    function minFee() public view returns (uint256) {
        return _minFee;
    }

    /**
     * @notice Calculate fee needed to transfer `amount` of tokens.
     */
    function estimateFee(uint256 value) public view override returns (uint256) {
        if (address(msg.sender).isContract()) {
            return 0;
        } else {
            return _estimateFee(value);
        }
    }

    /**
     * @dev Accept the ownership transfer. This is to make sure that the contract is
     * transferred to a working address
     *
     * Can only be called by the newly transfered owner.
     */
    function acceptOwnership() external {
        require(msg.sender == _newOwner, "VRC25: only new owner can accept ownership");
        address oldOwner = _owner;
        _owner = _newOwner;
        _newOwner = address(0);
        emit OwnershipTransferredVRC25(oldOwner, _owner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     *
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external virtual onlyOwner {
        require(newOwner != address(0), "VRC25: new owner is the zero address");
        _newOwner = newOwner;
    }

    /**
     * @notice Set minimum fee for each transaction
     *
     * Can only be called by the current owner.
     */
    function setFee(uint256 fee) external virtual onlyOwner {
        _minFee = fee;
        emit FeeUpdated(fee);
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     */
    function supportsInterface(bytes4 interfaceId) public view override virtual returns (bool) {
        return interfaceId == type(IVRC25).interfaceId;
    }

    /**
     * @notice Calculate fee needed to transfer `amount` of tokens.
     */
    function _estimateFee(uint256 value) internal view virtual returns (uint256);

    // Timelock implementation
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

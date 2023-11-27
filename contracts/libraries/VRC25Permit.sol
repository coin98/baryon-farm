// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

import "../interfaces/IVRC25Permit.sol";

import "./ECDSA.sol";
import "./EIP712.sol";

import "./VRC25.sol";

abstract contract VRC25Permit is VRC25, EIP712, IVRC25Permit {
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) private _nonces;

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external override view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Returns an the next unused nonce for an address.
     */
    function nonces(address owner) public view virtual override(IVRC25Permit) returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev See {IERC20Permit-permit}.
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(block.timestamp <= deadline, "VRC25: Permit expired");

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == owner, "VRC25: Invalid permit");

        uint256 fee = estimateFee(0);
        _approve(owner, spender, value);
        _chargeFeeFrom(owner, address(this), fee);
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    function _useNonce(address owner) internal returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        // It is important to do x++ and not ++x here.
        return _nonces[owner]++;
    }
}

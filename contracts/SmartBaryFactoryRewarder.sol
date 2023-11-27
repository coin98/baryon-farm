// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./interfaces/IVRC25.sol";
import "./interfaces/IWVIC.sol";

import "./libraries/AdvancedVRC25.sol";
import "./libraries/SafeMath.sol";

// File contracts/SmartBaryFactoryRewarder.sol
/// @title Smart Baryon Factory Rewarder
/// @notice Pool to hold reward minted from SmartBaryFactory
contract SmartBaryFactoryRewarder {
    address public WVIC_ADDRESS;

    using SafeMath for uint256;
    using AdvancedVRC25 for IVRC25;

    IVRC25[] public rewardTokens;
    uint256[] public rewardMultipliers;
    address private FACTORY_V2;

    /// @dev Maximum reward tokens can claim in single pool
    uint256 private constant MAX_REWARDS = 100;

    /// @dev Reward quantities remain for users
    mapping(address => mapping(uint256 => uint256)) private rewardDebts;

    /// @param _factoryV2 The address of the factory contract
    constructor(address _factoryV2, address _wvicAddress) {
        require(
            _factoryV2 != address(0),
            "SmartBaryFactoryRewarder: Invalid factory address"
        );

        FACTORY_V2 = _factoryV2;
        WVIC_ADDRESS = _wvicAddress;
    }

    modifier onlyBaryonFactory() {
        require(
            msg.sender == FACTORY_V2,
            "Only BaryonFactory can call this function."
        );
        _;
    }

    /**
     * @notice Receive native token
     */
    fallback() external payable {
    }

    /**
     * @notice Receive native token
     */
    receive() external payable {
    }

    /// @param _rewardTokens The address of each reward token
    /// @param _rewardMultipliers The amount of each reward token to be claimable
    /// @notice Each reward multiplier should matching with each reward tokens index
    function initialize(
        IVRC25[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers
    ) external onlyBaryonFactory {
        require(
            _rewardTokens.length > 0 &&
                _rewardTokens.length <= MAX_REWARDS &&
                _rewardTokens.length == _rewardMultipliers.length,
            "SmartBaryFactoryRewarder: Invalid input lengths"
        );

        for (uint256 i; i < _rewardTokens.length; ++i) {
            require(
                address(_rewardTokens[i]) != address(0),
                "SmartBaryFactoryRewarder: Cannot reward zero address"
            );
            require(
                _rewardMultipliers[i] > 0,
                "SmartBaryFactoryRewarder: Invalid multiplier"
            );
        }

        rewardTokens = _rewardTokens;
        rewardMultipliers = _rewardMultipliers;
    }

    /// @param user The address of deposit user
    /// @param harvestAmount The amount user can be claimable
    /// @notice Must deposit first before user can be claimed
    function claimReward(address user, uint256 harvestAmount)
        external
        onlyBaryonFactory
        returns (uint256[] memory totalReward)
    {
        totalReward = new uint256[](rewardTokens.length);


        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 pendingReward = rewardDebts[user][i].add(
                harvestAmount.mul(rewardMultipliers[i]).div(1e18)
            );

            uint256 rewardBal = rewardTokens[i].balanceOf(address(this));
            require(
                rewardBal > 0,
                "SmartBaryFactoryRewarder: Reward Balances must be greater than 0"
            );
            bool isOverPool = pendingReward >= rewardBal;

            rewardDebts[user][i] = isOverPool
                ? pendingReward.sub(rewardBal)
                : 0;
            uint256 claimRewardAmount = isOverPool ? rewardBal : pendingReward;
            if (claimRewardAmount > 0) {
                _transferOrUnwrapTo(rewardTokens[i], user, claimRewardAmount);
                totalReward[i] = claimRewardAmount;
            }
        }
        return totalReward;
    }

    /// @param user The address of deposit user
    /// @param harvestAmount The amount user can be claimable
    /// @notice Return current pending reward of deposit user
    function pendingClaimable(address user, uint256 harvestAmount)
        external
        view
        returns (IVRC25[] memory tokens, uint256[] memory amounts)
    {
        amounts = new uint256[](rewardTokens.length);
        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 pendingReward = rewardDebts[user][i].add(
                harvestAmount.mul(rewardMultipliers[i]).div(1e18)
            );
            uint256 rewardBal = rewardTokens[i].balanceOf(address(this));
            amounts[i] = pendingReward >= rewardBal ? rewardBal : pendingReward;
        }
        return (rewardTokens, amounts);
    }

    /// @notice Current state of reward tokens
    function getRewardTokens() external view returns (IVRC25[] memory) {
        return rewardTokens;
    }

    /// @notice Current state of reward multipliers
    function getRewardMultipliers() external view returns (uint256[] memory) {
        return rewardMultipliers;
    }

    /// @notice Baryon owner withdraw all tokens from pool
    function withdrawForOwner() external onlyBaryonFactory {
        for (uint256 i; i < rewardTokens.length; ++i) {
            uint256 tokenBalance = rewardTokens[i].balanceOf(address(this));

            if (tokenBalance > 0) {
                _transferOrUnwrapTo(rewardTokens[i], FACTORY_V2, tokenBalance);
            }
        }
    }

    /// @notice Baryon owner withdraw tokens from pool
    function withdrawTokens(address[] memory tokens)
        external
        onlyBaryonFactory
    {
        for (uint256 i; i < tokens.length; ++i) {
            IVRC25 _token = IVRC25(tokens[i]);
            uint256 tokenBalance = _token.balanceOf(address(this));

            if (tokenBalance > 0) {
                _transferOrUnwrapTo(_token, FACTORY_V2, tokenBalance);
            }
        }
    }

    /// @notice transfer VRC25 token to `recipient`. if the token is WVIC, unwrap it and send VIC to `recipient` instead
    function _transferOrUnwrapTo(IVRC25 token, address recipient, uint256 amount) internal {
        if(address(token) == WVIC_ADDRESS) {
            IWVIC(WVIC_ADDRESS).withdraw(amount);
            payable(recipient).transfer(amount);
        } else if(address(token) == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            token.safeTransfer(recipient, amount);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// File contracts/SmartBaryFactoryRewarder.sol
/// @title Smart Baryon Factory Rewarder
/// @notice Pool to hold reward minted from SmartBaryFactory

import "./VRC25.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";
contract SmartBaryFactoryRewarder is VRC25 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20[] public rewardTokens;
    uint256[] public rewardMultipliers;
    address private FACTORY_V2;

    /// @dev Maximum reward tokens can claim in single pool
    uint256 private constant MAX_REWARDS = 100;

    /// @dev Reward quantities remain for users
    mapping(address => mapping(uint256 => uint256)) private rewardDebts;

    /// @param _factoryV2 The address of the factory contract
    constructor(address _factoryV2, string memory name, string memory symbol, uint8 decimals_) VRC25(name, symbol, decimals_, 86400) {
        require(
            _factoryV2 != address(0),
            "SmartBaryFactoryRewarder: Invalid factory address"
        );

        FACTORY_V2 = _factoryV2;
    }

    function _estimateFee(uint256 value) internal view override returns (uint256) {
        if(value > minFee()) {
            return value;
        }
        return minFee();
    }

    modifier onlyBaryonFactory() {
        require(
            msg.sender == FACTORY_V2,
            "Only BaryonFactory can call this function."
        );
        _;
    }

    /// @param _rewardTokens The address of each reward token
    /// @param _rewardMultipliers The amount of each reward token to be claimable
    /// @notice Each reward multiplier should matching with each reward tokens index
    function initialize(
        IERC20[] memory _rewardTokens,
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
                rewardTokens[i].safeTransfer(user, claimRewardAmount);
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
        returns (IERC20[] memory tokens, uint256[] memory amounts)
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
    function getRewardTokens() external view returns (IERC20[] memory) {
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
                rewardTokens[i].safeTransfer(FACTORY_V2, tokenBalance);
            }
        }
    }

    /// @notice Baryon owner withdraw tokens from pool
    function withdrawTokens(address[] memory tokens)
        external
        onlyBaryonFactory
    {
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 _token = IERC20(tokens[i]);
            uint256 tokenBalance = _token.balanceOf(address(this));

            if (tokenBalance > 0) {
                _token.safeTransfer(FACTORY_V2, tokenBalance);
            }
        }
    }
}
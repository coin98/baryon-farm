// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Smart Baryon Factory
/// @notice Factory contract gives out a reward tokens per block.
import "./VRC25.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Operator.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/SafeERC20.sol";
import "./SmartBaryFactoryRewarder.sol";
import "./interfaces/IWVIC.sol";

contract SmartBaryFactory is VRC25, Operator {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public WVIC;

    /// @notice Info of each Deposited user.
    /// `amount` LP token amount
    /// `rewardDebt` The amount of user reward
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each pool.
    /// `rewardsStartTime` Block time when the rewards start to claimable.
    /// `accRewardPerShare` Each reward per share by total LP Supply
    /// `rewardsExpiration` Block time when the rewards per second stops.
    /// `lastRewardTime` Lastest pool reward updated
    /// `rewardPerSeconds` Reward to be claimable by seconds
    /// `oldReserveBalance` Total rewards token already deposited
    /// `claimedAmount` Total amount of rewards token already claimed
    struct PoolInfo {
        uint256 rewardsStartTime;
        uint256 accRewardPerShare;
        uint256 rewardsExpiration;
        uint256 lastRewardTime;
        uint256 rewardPerSeconds;
        uint256[] oldReserveBalance;
        uint256[] claimedAmount;
    }

    /// @notice Info of each pool pool.
    PoolInfo[] private poolInfo;
    /// @notice Address of the LP token for each pool pool.
    IERC20[] public lpToken;
    /// @notice Address of each `SmartBaryFactoryRewarder` contract in pool.
    SmartBaryFactoryRewarder[] public rewarder;
    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev List LP tokens already added
    mapping(address => bool) public listAddedLPs;

    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);

    event PoolAdded(
        uint256 indexed pid,
        uint256 rewardsStartTime,
        uint256 rewardsExpiration,
        uint256 rewardPerSecond,
        IERC20 indexed lpToken,
        address rewarder
    );
    event PoolSet(
        uint256 indexed pid,
        uint256 rewardsStartTime,
        uint256 rewardsExpiration,
        uint256 rewardPerSecond
    );
    event PoolUpdate(
        uint256 indexed pid,
        uint256 lastRewardTime,
        uint256 lpSupply,
        uint256 accRewardPerShare
    );

    event WithdrawMultiplePool(uint256[] indexed pid);
    event WithdrawPoolTokens(uint256 indexed pid, address[] tokens);
    event WithdrawMultiple(address[] tokens);

    constructor(string memory name, string memory symbol, uint8 decimals_, address _WVIC) VRC25(name, symbol, decimals_, 0){
        WVIC = _WVIC;
    }

    function _estimateFee(uint256 value) internal view override returns (uint256) {
        if(value > minFee()) {
            return value;
        }
        return minFee();
    }

    /// @notice Returns pool info by ID
    function getPoolInfo(uint256 pid) public view returns (PoolInfo memory) {
        return poolInfo[pid];
    }

    /// @notice Returns the size of all current pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Returns list of all lpTokens already added
    function lpTokens() external view returns (IERC20[] memory) {
        return lpToken;
    }

    /// @notice Check Block time start condition of each pool
    /// @param pool Pool to check block time
    function farmCheckStartTime(PoolInfo memory pool) internal view {
        require(
            block.timestamp >= pool.rewardsStartTime,
            "SmartBaryFactory: Invalid Start Time"
        );
    }

    /// @notice Check Block expiration time
    /// @param pool Pool to check block time
    function farmCheckExpirationTime(PoolInfo memory pool) internal view {
        require(
            block.timestamp < pool.rewardsExpiration,
            "SmartBaryFactory: Invalid Expiration Time"
        );
    }

    /// @notice Add rewarder pool
    function addPool(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds,
        address _lpToken
    ) external onlyOperator {
        uint256 tokenCode;
        assembly {
            tokenCode := extcodesize(_lpToken)
        }
        IERC20 lpTokenCall = IERC20(_lpToken);
        require(
            tokenCode > 0 && lpTokenCall.balanceOf(address(this)) >= 0,
            "SmartBaryFactory: Invalid token code"
        );

        massUpdateAllPools();
        add(
            _rewardTokens,
            _rewardMultipliers,
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds,
            lpTokenCall
        );
    }

    /// @notice Add a new LP to the pool. Can only be called by the operator.
    /// DO NOT add the same LP token more than once.
    function add(
        IERC20[] memory _rewardTokens,
        uint256[] memory _rewardMultipliers,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds,
        IERC20 _lpToken
    ) internal {
        require(
            listAddedLPs[address(_lpToken)] == false,
            "SmartBaryFactory: LP token already added"
        );

        _rewardsStartTime = _rewardsStartTime > block.timestamp
            ? _rewardsStartTime
            : block.timestamp;

        require(
            _rewardsExpiration > _rewardsStartTime,
            "SmartBaryFactory: Invalid time"
        );
        require(
            _rewardsExpiration > block.timestamp,
            "SmartBaryFactory: Invalid expiration time"
        );

        bytes memory bytecode = type(SmartBaryFactoryRewarder).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this), "Baryon Farm Rewarder", "BFR", 18));
        bytes32 salt = keccak256(abi.encodePacked(_lpToken, _rewardsStartTime));
        address baryonFarmRewarder;

        assembly {
            baryonFarmRewarder := create2(
                0,
                add(bytecode, 32),
                mload(bytecode),
                salt
            )
        }

        // address baryonFarmRewarder = address(new SmartBaryFactoryRewarder(address(this), "Baryon Farm Rewarder", "BFR", 18));

        // Deposit token to pool before add new pool
        uint256 rewardAmountEstTotal = (_rewardsExpiration -
            _rewardsStartTime) * _rewardPerSeconds.div(1e18);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _rewardTokens[i].safeTransferFrom(
                msg.sender,
                baryonFarmRewarder,
                rewardAmountEstTotal * _rewardMultipliers[i]
            );
        }

        SmartBaryFactoryRewarder(baryonFarmRewarder).initialize(
            _rewardTokens,
            _rewardMultipliers
        );

        lpToken.push(_lpToken);
        rewarder.push(SmartBaryFactoryRewarder(baryonFarmRewarder));

        poolInfo.push(
            PoolInfo({
                rewardsStartTime: _rewardsStartTime,
                rewardsExpiration: _rewardsExpiration,
                rewardPerSeconds: _rewardPerSeconds,
                lastRewardTime: _rewardsStartTime,
                accRewardPerShare: 0,
                claimedAmount: new uint256[](_rewardTokens.length),
                oldReserveBalance: new uint256[](_rewardTokens.length)
            })
        );

        listAddedLPs[address(_lpToken)] = true;
        emit PoolAdded(
            lpToken.length.sub(1),
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds,
            _lpToken,
            baryonFarmRewarder
        );
    }

    /// @notice Change information for one pool
    function setPool(
        uint256 _pid,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds
    ) external onlyOwner whenUnlock {
        massUpdateAllPools();
        set(_pid, _rewardsStartTime, _rewardsExpiration, _rewardPerSeconds);
    }

    /// @notice Update the given pool's information
    function set(
        uint256 _pid,
        uint256 _rewardsStartTime,
        uint256 _rewardsExpiration,
        uint256 _rewardPerSeconds
    ) internal {
        _rewardsStartTime = _rewardsStartTime > block.timestamp
            ? _rewardsStartTime
            : block.timestamp;

        require(
            _rewardsExpiration > _rewardsStartTime,
            "SmartBaryFactory: Invalid time"
        );
        require(
            _rewardsExpiration > block.timestamp,
            "SmartBaryFactory: Invalid expiration time"
        );

        PoolInfo storage pool = poolInfo[_pid];
        SmartBaryFactoryRewarder factoryRewarder = rewarder[_pid];
        IERC20[] memory tokens = factoryRewarder.getRewardTokens();
        uint256[] memory multipliers = factoryRewarder.getRewardMultipliers();

        uint256 oldExpiration = block.timestamp > pool.rewardsExpiration
            ? pool.rewardsExpiration
            : block.timestamp;
        uint256 rewardAmountEstTotal = (_rewardsExpiration -
            _rewardsStartTime) * _rewardPerSeconds.div(1e18);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(
                address(factoryRewarder)
            );
            uint256 rewardMultiplier = multipliers[i];
            // Deposit token to pool if not enough balance

            uint256 oldReserveBalance = (oldExpiration -
                pool.rewardsStartTime) *
                pool.rewardPerSeconds +
                pool.oldReserveBalance[i];

            if (
                oldReserveBalance > 0 &&
                oldReserveBalance >= pool.claimedAmount[i]
            ) {
                oldReserveBalance = oldReserveBalance.sub(
                    pool.claimedAmount[i]
                );

                uint256 remainReserveReward = tokenBalance > oldReserveBalance
                    ? tokenBalance - oldReserveBalance
                    : 0;
                uint256 amountNeedToTransferMore = (rewardAmountEstTotal *
                    rewardMultiplier) > remainReserveReward
                    ? (rewardAmountEstTotal * rewardMultiplier) -
                        remainReserveReward
                    : 0;
                IERC20(tokens[i]).safeTransferFrom(
                    msg.sender,
                    address(factoryRewarder),
                    amountNeedToTransferMore
                );
                pool.oldReserveBalance[i] = oldReserveBalance;
                pool.claimedAmount[i] = 0;
            }
        }
        // Update information
        pool.rewardsStartTime = _rewardsStartTime;
        pool.rewardsExpiration = _rewardsExpiration;
        pool.rewardPerSeconds = _rewardPerSeconds;
        pool.lastRewardTime = _rewardsStartTime;

        emit PoolSet(
            _pid,
            _rewardsStartTime,
            _rewardsExpiration,
            _rewardPerSeconds
        );
    }

    /// @notice Getter the pending reward for a given user.
    /// @param _pid The index of pool.
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = lpToken[_pid].balanceOf(address(this));

        if (block.timestamp < pool.rewardsStartTime) {
            pending = 0;
        } else {
            if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
                uint256 time = block.timestamp <= pool.rewardsExpiration
                    ? block.timestamp.sub(pool.lastRewardTime) // Accrue rewards until now
                    : pool.rewardsExpiration > pool.lastRewardTime
                    ? pool.rewardsExpiration.sub(pool.lastRewardTime) // Accrue rewards until expiration
                    : 0; // No rewards to accrue
                uint256 reward = time.mul(pool.rewardPerSeconds);
                accRewardPerShare = accRewardPerShare.add(
                    reward.mul(ACC_REWARD_PRECISION) / lpSupply
                );
            }
            pending = uint256(
                user.amount.mul(accRewardPerShare) / ACC_REWARD_PRECISION
            ).sub(user.rewardDebt);
        }
    }

    /// @notice Update reward variables for all pools
    /// @param pids Pool IDs of all to be updated
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables for all pools.
    function massUpdateAllPools() public {
        uint256 len = poolInfo.length;
        for (uint256 pid = 0; pid < len; ++pid) {
            updatePool(pid);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool.
    /// @return pool Returns the pool updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (
            block.timestamp > pool.lastRewardTime &&
            block.timestamp > pool.rewardsStartTime
        ) {
            uint256 lpSupply = lpToken[pid].balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 time = block.timestamp <= pool.rewardsExpiration
                    ? block.timestamp.sub(pool.lastRewardTime) // Accrue rewards until now
                    : pool.rewardsExpiration > pool.lastRewardTime
                    ? pool.rewardsExpiration.sub(pool.lastRewardTime) // Accrue rewards until expiration
                    : 0; // No rewards to accrue
                uint256 reward = time.mul(pool.rewardPerSeconds);
                pool.accRewardPerShare = pool.accRewardPerShare.add(
                    (reward.mul(ACC_REWARD_PRECISION) / lpSupply)
                );
            }
            pool.lastRewardTime = block.timestamp;
            poolInfo[pid] = pool;
            emit PoolUpdate(
                pid,
                pool.lastRewardTime,
                lpSupply,
                pool.accRewardPerShare
            );
        }
    }

    /// @notice Update the reward claimed each times deposit and harvest.
    /// @param pid The index of the pool.
    /// @param rewardClaimed The reward claimed of the pool.
    function updateClaimedReward(uint256 pid, uint256[] memory rewardClaimed)
        internal
    {
        PoolInfo storage pool = poolInfo[pid];

        for (uint256 i = 0; i < rewarder[pid].getRewardTokens().length; i++) {
            pool.claimedAmount[i] = pool.claimedAmount[i].add(rewardClaimed[i]);
        }
    }

    /// @notice Deposit LP tokens to Pool for reward allocation.
    /// @param pid The index of the pool.
    /// @param amount LP token amount to deposit.
    function deposit(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);
        farmCheckExpirationTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 currentBalance = lpToken[pid].balanceOf(address(this));
        lpToken[pid].safeTransferFrom(to, address(this), amount);
        uint256 afterBalance = lpToken[pid].balanceOf(address(this));
        uint256 realAmount = afterBalance.sub(currentBalance);

        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            uint256[] memory rewardClaimed = _rewarder.claimReward(
                to,
                _pendingReward
            );

            updateClaimedReward(pid, rewardClaimed);
        }

        // Updated information
        user.amount = user.amount.add(realAmount);
        user.rewardDebt = accumulatedReward.add(
            uint256(
                realAmount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
            )
        );

        emit Deposit(to, pid, realAmount, to);
    }


    /// @notice Deposit LP tokens (VIC) to Pool for reward allocation.
    /// @param pid The index of the pool.
    /// @param amount LP token amount to deposit.
    function depositVIC(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);
        farmCheckExpirationTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 currentBalance = lpToken[pid].balanceOf(address(this));

        IWVIC(WVIC).deposit{value: amount}();

        lpToken[pid].safeTransferFrom(to, address(this), amount);

        uint256 afterBalance = lpToken[pid].balanceOf(address(this));
        uint256 realAmount = afterBalance.sub(currentBalance);

        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            uint256[] memory rewardClaimed = _rewarder.claimReward(
                to,
                _pendingReward
            );

            updateClaimedReward(pid, rewardClaimed);
        }

        // Updated information
        user.amount = user.amount.add(realAmount);
        user.rewardDebt = accumulatedReward.add(
            uint256(
                realAmount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
            )
        );

        emit Deposit(to, pid, realAmount, to);
    }

    /// @notice Harvest reward for deposited user
    /// @param pid The index of the pool.
    function harvest(uint256 pid) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        // Updated information
        user.rewardDebt = accumulatedReward;

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            uint256[] memory rewardClaimed = _rewarder.claimReward(
                to,
                _pendingReward
            );
            updateClaimedReward(pid, rewardClaimed);
        }

        emit Harvest(to, pid, _pendingReward);
    }

    /// @notice Harvest reward for deposited user
    /// @param pid The index of the pool.
    function harvestVIC(uint256 pid) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);

        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        // Updated information
        user.rewardDebt = accumulatedReward;

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            uint256[] memory rewardClaimed = _rewarder.claimRewardVIC(
                to,
                _pendingReward
            );
            updateClaimedReward(pid, rewardClaimed);
        }

        emit Harvest(to, pid, _pendingReward);
    }

    /// @notice Withdraw LP tokens from Factory and harvest reward for deposited user.
    /// @param pid The index of the pool.
    /// @param amount LP token amount to withdraw.
    function withdrawAndHarvest(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        farmCheckStartTime(pool);
        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 accumulatedReward = uint256(
            user.amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION
        );
        uint256 _pendingReward = accumulatedReward.sub(user.rewardDebt);

        // Updated information
        user.rewardDebt = accumulatedReward.sub(
            uint256(amount.mul(pool.accRewardPerShare) / ACC_REWARD_PRECISION)
        );
        user.amount = user.amount.sub(amount);

        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            uint256[] memory rewardClaimed = _rewarder.claimReward(
                to,
                _pendingReward
            );
            updateClaimedReward(pid, rewardClaimed);
        }

        lpToken[pid].safeTransfer(to, amount);


        emit Withdraw(to, pid, amount, to);
        emit Harvest(to, pid, _pendingReward);
    }

    /// @notice Emergency withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool.
    function emergencyWithdraw(uint256 pid) public {
        address to = msg.sender;

        UserInfo storage user = userInfo[pid][to];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(to, pid, amount, to);
    }

    /// @notice Withdraw all token reward in pool
    /// @param pid The index of the pool.
    function withdrawMultiplePool(uint256[] calldata pid)
        external
        onlyOwner
        whenUnlock
    {
        for (uint256 i = 0; i < pid.length; i++) {
            SmartBaryFactoryRewarder _rewarder = rewarder[pid[i]];
            if (address(_rewarder) != address(0)) {
                _rewarder.withdrawForOwner();
            }
        }
        emit WithdrawMultiplePool(pid);
    }

    /// @notice Withdraw the token from the pool
    /// @param pid The index of the pool.
    /// @param tokens The token contract token that want to withdraw of the pool
    function withdrawPoolTokens(uint256 pid, address[] calldata tokens)
        external
        onlyOperator
    {
        SmartBaryFactoryRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.withdrawTokens(tokens);
        }
        emit WithdrawPoolTokens(pid, tokens);
    }

    /// @notice Withdraw all token from all pool ( not use this for LP tokens )
    /// @param tokens The token contract that want to withdraw from all pool
    function withdrawMultiple(address[] calldata tokens) external onlyOperator {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                payable(msg.sender).transfer(address(this).balance);
            } else {
                IERC20 token = IERC20(tokens[i]);
                uint256 tokenBalance = token.balanceOf(address(this));
                if (tokenBalance > 0) {
                    token.safeTransfer(msg.sender, tokenBalance);
                }
            }
        }
        emit WithdrawMultiple(tokens);
    }

    function safeTransferVIC(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: VIC_TRANSFER_FAILED');
    }
}



import { BigNumberish } from "ethers";
import { ethers, network } from "hardhat";
import {
  loadFixture,
  time,
  mine,
} from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  SmartBaryFactory,
  SmartBaryFactoryRewarder,
  TestERC20,
  TestERC721,
} from "../typechain-types";
import { deployFixture } from "./shared/fixtures";
import { parseEther } from "ethers/lib/utils";

let owner: SignerWithAddress;
let acc1: SignerWithAddress;
let acc2: SignerWithAddress;

let factory: SmartBaryFactory;
let rewarder: SmartBaryFactoryRewarder;
let usdt: TestERC20;
let usdc: TestERC20;
let starship: TestERC721;

let rewardPerSecond: BigNumberish;
let rewardMultiplierUsdt: BigNumberish;
let rewardMultiplierUsdc: BigNumberish;

let rewardStartTime: number;
let rewardExpiration: number;

let snapshotId: string;

const poolWith2Tokens = async function () {
  const tx = await factory
    .connect(owner)
    .addPool(
      [usdt.address, usdc.address],
      [rewardMultiplierUsdt, rewardMultiplierUsdc],
      rewardStartTime,
      rewardExpiration,
      rewardPerSecond,
      starship.address
    );
  let deployPoolReceipt = await tx.wait();

  // Get event PoolAdded
  let poolAddedEvent = deployPoolReceipt.events?.find(
    (event) => event.event === "PoolAdded"
  );
  let rewarderAddress = poolAddedEvent?.args?.rewarder;
  const Rewarder = await ethers.getContractFactory("SmartBaryFactoryRewarder");
  rewarder = Rewarder.attach(rewarderAddress);
};

const poolWithToken = async function () {
  const tx = await factory
    .connect(owner)
    .addPool(
      [usdt.address],
      [rewardMultiplierUsdt],
      rewardStartTime,
      rewardExpiration,
      rewardPerSecond,
      starship.address
    );
  let deployPoolReceipt = await tx.wait();

  // Get event PoolAdded
  let poolAddedEvent = deployPoolReceipt.events?.find(
    (event) => event.event === "PoolAdded"
  );
  let rewarderAddress = poolAddedEvent?.args?.rewarder;
  const Rewarder = await ethers.getContractFactory("SmartBaryFactoryRewarder");
  rewarder = Rewarder.attach(rewarderAddress);
};

describe("Smart Baryon Factory", function () {
  before(async function () {
    let fixtures = await loadFixture(deployFixture);
    owner = fixtures.owner;
    acc1 = fixtures.acc1;
    acc2 = fixtures.acc2;

    factory = fixtures.smartBaryFactory;

    usdt = fixtures.usdt;
    usdc = fixtures.usdc;
    starship = fixtures.starship;

    rewardPerSecond = fixtures.rewardPerSecond;
    rewardMultiplierUsdt = fixtures.rewardMultiplierUsdt;
    rewardMultiplierUsdc = fixtures.rewardMultiplierUsdc;
    rewardExpiration = fixtures.rewardExpiration;
    rewardStartTime = fixtures.rewardStartTime;
  });

  beforeEach(async function () {
    snapshotId = await network.provider.send("evm_snapshot");
  });

  afterEach(async function () {
    await network.provider.send("evm_revert", [snapshotId]);
  });

  it("Initial state", async function () {
    expect(await factory.owner()).to.equal(owner.address);
    expect(await usdt.balanceOf(owner.address)).to.equal(parseEther("10000"));
  });

  describe("Create new pool", function () {
    context("When owner add new pool", async function () {
      it("Should add new pool", async function () {
        const tx = await factory
          .connect(owner)
          .addPool(
            [usdt.address],
            [rewardMultiplierUsdt],
            rewardStartTime,
            rewardExpiration,
            rewardPerSecond,
            starship.address
          );
        await expect(tx).to.emit(factory, "PoolAdded");
        await expect(tx).to.changeTokenBalances(
          usdt,
          [owner],
          [parseEther("-1000")]
        );
      });

      it("Should get pool info", async function () {
        await factory
          .connect(owner)
          .addPool(
            [usdt.address],
            [rewardMultiplierUsdt],
            rewardStartTime,
            rewardExpiration,
            rewardPerSecond,
            starship.address
          );
        const pool = await factory.getPoolInfo(BigInt(0));
        expect(pool.rewardPerSeconds).to.equal(rewardPerSecond);
        expect(pool.rewardsStartTime).to.equal(rewardStartTime);
        expect(pool.rewardsExpiration).to.equal(rewardExpiration);
      });
    });

    context("When non-owner add new pool", async function () {
      it("Should revert", async function () {
        await expect(
          factory
            .connect(acc1)
            .addPool(
              [usdt.address],
              [rewardMultiplierUsdt],
              rewardStartTime,
              rewardExpiration,
              rewardPerSecond,
              starship.address
            )
        ).to.be.revertedWith("Ownable: Caller is not the operator");
      });
    });

    context(
      "When owner add new pool with reward expiration less than reward start time",
      function () {
        it("Should revert", async function () {
          await expect(
            factory
              .connect(owner)
              .addPool(
                [usdt.address],
                [rewardMultiplierUsdt],
                rewardStartTime,
                rewardStartTime - 100,
                rewardPerSecond,
                starship.address
              )
          ).to.be.revertedWith("SmartBaryFactory: Invalid time");
        });
      }
    );

    context("When add the same LP token", async function () {
      it("Should revert", async function () {
        await factory
          .connect(owner)
          .addPool(
            [usdt.address],
            [rewardMultiplierUsdt],
            rewardStartTime,
            rewardExpiration,
            rewardPerSecond,
            starship.address
          );
        await expect(
          factory
            .connect(owner)
            .addPool(
              [usdt.address],
              [rewardMultiplierUsdt],
              rewardStartTime,
              rewardExpiration,
              rewardPerSecond,
              starship.address
            )
        ).to.be.revertedWith("SmartBaryFactory: LP token already added");
      });
    });

    context("Add pool with 2 reward tokens", async function () {
      it("Should add pool", async function () {
        await factory
          .connect(owner)
          .addPool(
            [usdt.address, usdc.address],
            [rewardMultiplierUsdt, rewardMultiplierUsdc],
            rewardStartTime,
            rewardExpiration,
            rewardPerSecond,
            starship.address
          );
        const pool = await factory.getPoolInfo(BigInt(0));
        expect(pool.rewardPerSeconds).to.equal(rewardPerSecond);
        expect(pool.rewardsStartTime).to.equal(rewardStartTime);
        expect(pool.rewardsExpiration).to.equal(rewardExpiration);
      });
    });
  });

  describe("Deposit", function () {
    let poolId: BigNumberish;

    beforeEach(async function () {
      await poolWithToken();
      poolId = BigInt(0);
    });

    context("When user deposit", async function () {
      it("Should deposit", async function () {
        await time.increaseTo(rewardStartTime);
        const tx = await factory.connect(acc1).deposit(poolId, [1]);
        await expect(tx).to.emit(factory, "Deposit");
        await expect(tx).to.changeTokenBalances(
          starship,
          [acc1, factory.address],
          [-1, 1]
        );
      });

      it("Should get user info", async function () {
        await time.increaseTo(rewardStartTime);
        await factory.connect(acc1).deposit(poolId, [1]);
        const userInfo = await factory.userInfo(poolId, acc1.address);
        expect(userInfo.amount).to.equal(1);
      });

      it("Should update pool info", async function () {
        await time.increaseTo(rewardStartTime);
        await factory.connect(acc1).deposit(poolId, [1]);
        const poolInfo = await factory.getPoolInfo(poolId);
        expect(poolInfo.rewardPerSeconds).to.equal(rewardPerSecond);
        expect(poolInfo.rewardsStartTime).to.equal(rewardStartTime);
        expect(poolInfo.rewardsExpiration).to.equal(rewardExpiration);
      });
    });

    context("When user deposit with invalid token", async function () {
      it("Should revert", async function () {
        await time.increaseTo(rewardStartTime);
        await expect(
          factory.connect(acc1).deposit(poolId, [0])
        ).to.be.revertedWith("ERC721: invalid token ID");
      });
    });

    context("When 2 users deposit", async function () {
      it("Should update user info", async function () {
        await time.increaseTo(rewardStartTime);
        await factory.connect(acc1).deposit(poolId, [1]);
        await factory.connect(acc2).deposit(poolId, [2]);
        const userInfo = await factory.userInfo(poolId, acc1.address);
        const userInfo2 = await factory.userInfo(poolId, acc2.address);
        expect(userInfo.amount).to.equal(1);
        expect(userInfo2.amount).to.equal(1);
      });
    });

    context("Deposit at half of the time", async function () {
      it("Should return half of the reward", async function () {
        await time.setNextBlockTimestamp(rewardStartTime + 50);
        await factory.connect(acc1).deposit(poolId, [1]);
        await time.setNextBlockTimestamp(rewardExpiration + 1);
        const tx = await factory.connect(acc1).withdrawAndHarvest(poolId, [1]);
        await expect(tx).to.changeTokenBalances(
          usdt,
          [acc1],
          [parseEther("500")]
        );
      });
    });
  });

  describe("Withdraw", function () {
    beforeEach(async function () {
      const tx = await factory
        .connect(owner)
        .addPool(
          [usdt.address],
          [rewardMultiplierUsdt],
          rewardStartTime,
          rewardExpiration,
          rewardPerSecond,
          starship.address
        );
      let deployPoolReceipt = await tx.wait();

      // Get event PoolAdded
      let poolAddedEvent = deployPoolReceipt.events?.find(
        (event) => event.event === "PoolAdded"
      );
      let rewarderAddress = poolAddedEvent?.args?.rewarder;
      const Rewarder = await ethers.getContractFactory(
        "SmartBaryFactoryRewarder"
      );
      rewarder = Rewarder.attach(rewarderAddress);
    });

    context("When user withdraw success", async function () {
      it("Should return balance", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.increaseTo(rewardExpiration + 1);
        const tx = await factory
          .connect(acc1)
          .withdrawAndHarvest(BigInt(0), [1]);
        await expect(tx).to.changeTokenBalances(
          starship,
          [acc1, factory.address],
          [1, -1]
        );
        await expect(tx).to.changeTokenBalances(
          usdt,
          [acc1, rewarder.address],
          [parseEther("1000"), parseEther("-1000")]
        );
      });

      it("Should emit", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.increaseTo(rewardExpiration + 1);
        const tx = await factory
          .connect(acc1)
          .withdrawAndHarvest(BigInt(0), [1]);
        await expect(tx).to.emit(factory, "Withdraw");
        await expect(tx).to.emit(factory, "Harvest");
      });
    });

    context("When user withdraw emergency", async function () {
      it("Should emergency withdraw", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        const tx = await factory.connect(acc1).emergencyWithdraw(BigInt(0));
        await expect(tx).to.emit(factory, "EmergencyWithdraw");
        await expect(tx).to.changeTokenBalances(
          starship,
          [acc1, factory.address],
          [1, -1]
        );
      });
    });

    context("When user withdraw with invalid token", async function () {
      it("Should revert", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.increaseTo(rewardExpiration + 1);
        await expect(
          factory.connect(acc1).withdrawAndHarvest(BigInt(0), [2])
        ).to.be.revertedWith("SmartBaryFactory: Token ID not found");
      });
    });

    context("When user withdraw half of the time", async function () {
      it("Should return half of the reward", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardExpiration - 50);
        const tx = await factory
          .connect(acc1)
          .withdrawAndHarvest(BigInt(0), [1]);
        await expect(tx).to.changeTokenBalances(
          usdt,
          [acc1, rewarder.address],
          [parseEther("500"), parseEther("-500")]
        );
      });

      context("2 user withdraw", async function () {
        it("Should return reward", async function () {
          await time.setNextBlockTimestamp(rewardStartTime);
          await factory.connect(acc1).deposit(BigInt(0), [1]);

          await time.setNextBlockTimestamp(rewardStartTime + 10);
          await factory.connect(acc2).deposit(BigInt(0), [2]);

          await time.setNextBlockTimestamp(rewardExpiration - 50);
          const tx1 = await factory
            .connect(acc1)
            .withdrawAndHarvest(BigInt(0), [1]);

          await time.setNextBlockTimestamp(rewardExpiration + 1);

          const tx2 = await factory
            .connect(acc2)
            .withdrawAndHarvest(BigInt(0), [2]);

          await expect(tx1).to.changeTokenBalances(
            usdt,
            [acc1, rewarder.address],
            [parseEther("300"), parseEther("-300")]
          );
          await expect(tx2).to.changeTokenBalances(
            usdt,
            [acc2, rewarder.address],
            [parseEther("700"), parseEther("-700")]
          );
        });
      });

      context("When withdraw one of many tokens", async function () {});
    });
  });

  describe("Harvest", function () {
    beforeEach(async function () {
      await poolWithToken();
    });

    context("When user harvest successful", async function () {
      it("Should return reward", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardStartTime + 50);
        const tx = await factory.connect(acc1).harvest(BigInt(0));
        await expect(tx).to.changeTokenBalances(
          usdt,
          [acc1, rewarder.address],
          [parseEther("500"), parseEther("-500")]
        );
      });

      it("Should emit", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardStartTime + 50);
        const tx = await factory.connect(acc1).harvest(BigInt(0));
        await expect(tx).to.emit(factory, "Harvest");
      });
    });

    context("When user harvest twice", async function () {
      it("Should return reward", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardStartTime + 50);
        const tx1 = await factory.connect(acc1).harvest(BigInt(0));
        await time.setNextBlockTimestamp(rewardStartTime + 80);
        const tx2 = await factory.connect(acc1).harvest(BigInt(0));
        await expect(tx1).to.changeTokenBalances(
          usdt,
          [acc1, rewarder.address],
          [parseEther("500"), parseEther("-500")]
        );
        await expect(tx2).to.changeTokenBalances(
          usdt,
          [acc1, rewarder.address],
          [parseEther("300"), parseEther("-300")]
        );
      });
    });
  });

  describe("Set pool", function () {
    let poolId: BigNumberish;

    beforeEach(async function () {
      await poolWithToken();
      poolId = BigInt(0);
    });

    context("When owner set pool", async function () {
      it("Should set pool", async function () {
        const setPoolSelector = factory.interface.getSighash("setPool");
        await factory.connect(owner).unlock(setPoolSelector);
        await time.increaseTo((await time.latest()) + 86400);
        await usdt.connect(owner).approve(factory.address, parseEther("1000"));
        await factory
          .connect(owner)
          .setPool(
            poolId,
            rewardStartTime + 100 + 86400,
            rewardExpiration + 100 + 86400,
            rewardPerSecond
          );
        const pool = await factory.getPoolInfo(poolId);
        expect(pool.rewardPerSeconds).to.equal(rewardPerSecond);
        expect(pool.rewardsStartTime).to.equal(rewardStartTime + 100 + 86400);
        expect(pool.rewardsExpiration).to.equal(rewardExpiration + 100 + 86400);
      });
    });

    context("Set pool when isn't unlock", async function () {
      it("Should revert", async function () {
        await expect(
          factory
            .connect(owner)
            .setPool(
              poolId,
              BigInt(rewardStartTime + 100),
              BigInt(rewardExpiration + 100),
              rewardPerSecond
            )
        ).to.be.revertedWith("LockSchedule: contract is locked");
      });
    });

    context("When non-owner set pool", async function () {
      it("Should revert", async function () {
        await expect(
          factory
            .connect(acc1)
            .setPool(poolId, rewardStartTime, rewardExpiration, rewardPerSecond)
        ).to.be.revertedWith("Ownable: Caller is not the owner");
      });
    });
  });

  describe("Pending reward", function () {
    beforeEach(async function () {
      await poolWithToken();
    });

    context("Should check pending reward", async function () {
      it("Pending reward exist", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardStartTime + 50);
        await mine();
        const pendingReward = await factory.pendingReward(
          BigInt(0),
          acc1.address
        );
        expect(pendingReward).to.equal(parseEther("500"));
      });

      it("Pending reward not exist", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await factory.connect(acc1).deposit(BigInt(0), [1]);
        await time.setNextBlockTimestamp(rewardExpiration + 1);
        await mine();
        const pendingReward = await factory.pendingReward(
          BigInt(0),
          acc2.address
        );
        expect(pendingReward).to.equal(0);
      });
    });
  });

  describe("Withdraw multiple tokens", function () {
    beforeEach(async function () {
      await poolWithToken();
    });

    context("When owner withdraw", async function () {
      it("Should emit", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        const tx = await factory
          .connect(owner)
          .withdrawMultiple([usdt.address]);
        await expect(tx).to.emit(factory, "WithdrawMultiple");
      });
    });

    context("When non-owner withdraw", async function () {
      it("Should revert", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await expect(
          factory.connect(acc1).withdrawMultiple([usdt.address])
        ).to.be.revertedWith("Ownable: Caller is not the operator");
      });
    });
  });

  describe("Withdraw pool token", function () {
    beforeEach(async function () {
      await poolWithToken();
    });

    context("When owner withdraw", async function () {
      it("Should withdraw", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);

        const tx = await factory
          .connect(owner)
          .withdrawPoolTokens(BigInt(0), [usdt.address]);
        await expect(tx).to.changeTokenBalances(
          usdt,
          [factory.address],
          [parseEther("1000")]
        );
      });

      it("Should emit", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        const tx = await factory
          .connect(owner)
          .withdrawPoolTokens(BigInt(0), [usdt.address]);
        await expect(tx).to.emit(factory, "WithdrawPoolTokens");
      });
    });

    context("When non-owner withdraw", async function () {
      it("Should revert", async function () {
        await time.setNextBlockTimestamp(rewardStartTime);
        await expect(
          factory.connect(acc1).withdrawPoolTokens(BigInt(0), [usdt.address])
        ).to.be.revertedWith("Ownable: Caller is not the operator");
      });
    });
  });

  describe("Withdraw multiple pool", function () {
    beforeEach(async function () {
      await poolWithToken();
    });

    context("When owner withdraw but isn't unlock", async function () {
      it("Should revert when isn't unlocked", async function () {
        await expect(
          factory.connect(owner).withdrawMultiplePool([BigInt(0)])
        ).to.be.revertedWith("LockSchedule: contract is locked");
      });

      it("Should withdraw when unlocked", async function () {
        const withdrawMultiplePoolSelector = factory.interface.getSighash(
          "withdrawMultiplePool"
        );
        await factory.connect(owner).unlock(withdrawMultiplePoolSelector);
        await time.increaseTo((await time.latest()) + 86401);
        const tx = await factory
          .connect(owner)
          .withdrawMultiplePool([BigInt(0)]);
        await expect(tx).to.changeTokenBalances(
          usdt,
          [factory],
          [parseEther("1000")]
        );
      });
    });

    context("When non-owner withdraw", async function () {
      it("Should revert", async function () {
        await expect(
          factory.connect(acc1).withdrawMultiplePool([BigInt(0)])
        ).to.be.revertedWith("Ownable: Caller is not the owner");
      });
    });
  });

  describe("Rewarder", function () {
    context("Pool with 1 token", async function () {
      beforeEach(async function () {
        await poolWithToken();
      });

      it("Should return reward multiplier", async function () {
        const rewardMultiplier = await rewarder.getRewardMultipliers();
        expect(rewardMultiplier[0]).to.equal(parseEther("1"));
      });
      it("Should return reward tokens", async function () {
        const rewardTokens = await rewarder.getRewardTokens();
        expect(rewardTokens[0]).to.equal(usdt.address);
      });
    });

    context("Pool with 2 tokens", async function () {
      beforeEach(async function () {
        await poolWith2Tokens();
      });

      it("Should return reward multiplier", async function () {
        const rewardMultiplier = await rewarder.getRewardMultipliers();
        expect(rewardMultiplier[0]).to.equal(parseEther("1"));
        expect(rewardMultiplier[1]).to.equal(parseEther("2"));
      });

      it("Should return reward tokens", async function () {
        const rewardTokens = await rewarder.getRewardTokens();
        expect(rewardTokens[0]).to.equal(usdt.address);
        expect(rewardTokens[1]).to.equal(usdc.address);
      });
    });
  });
});

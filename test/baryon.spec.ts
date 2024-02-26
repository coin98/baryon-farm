import { ethers } from "hardhat";
import { SmartBaryFactory, SmartBaryFactoryRewarder, SmartBaryFactory__factory, TestERC20, TestERC20__factory, TestERC721, TestERC721__factory } from "../typechain-types";
import { expect } from "chai";
import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/dist/src/signer-with-address";
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

describe("Smart Baryon Factory", function () {
  let factory: SmartBaryFactory;
  let rewarder: SmartBaryFactoryRewarder;
  let ftToken: TestERC20;
  let nftToken: TestERC721;
  let snapshotTime: number;

  let owner: SignerWithAddress;
  let user: SignerWithAddress;
  let user2: SignerWithAddress;
  let user3: SignerWithAddress;

  before(async function () {
    [owner, user, user2, user3] = await ethers.getSigners();

    const BaryonFactory: SmartBaryFactory__factory = await ethers.getContractFactory("SmartBaryFactory");
    factory = await BaryonFactory.connect(owner).deploy();
    await factory.waitForDeployment();

    const ERC20: TestERC20__factory = await ethers.getContractFactory("TestERC20");
    ftToken = await ERC20.connect(owner).deploy(BigInt(1000000000000000000000000));

    const ERC721: TestERC721__factory = await ethers.getContractFactory("TestERC721");
    nftToken = await ERC721.deploy("TestNFT", "TNFT");

    await ftToken.waitForDeployment();
    await nftToken.waitForDeployment();

    snapshotTime = Math.floor(Date.now() / 1000);
  });

  it("Add new pool", async () => {
    await ftToken.connect(owner).approve(await factory.getAddress(), BigInt(1000000000000000000).toString());

    await factory.connect(owner).addPool(
      [await ftToken.getAddress()],
      [BigInt(1000000).toString()],
      BigInt(snapshotTime),
      BigInt(1000000 + snapshotTime),
      BigInt(1000000).toString(),
      await nftToken.getAddress()
    );

    const pool = await factory.getPoolInfo(BigInt(0));
  });

  it("Deposit reward token to rewarder", async () => {
    const rewarderAddress = await factory.rewarder(BigInt(0));
    rewarder = await ethers.getContractAt("SmartBaryFactoryRewarder", rewarderAddress);
    await ftToken.connect(owner).transfer(rewarderAddress, BigInt(10000000000000));
  })

  it("User deposit", async () => {
    let userInfo = await factory.userInfo(BigInt(0), user.address);
    // Mint a NFT
    await nftToken.connect(owner).mint(user.address, BigInt(0));
    expect(await nftToken.balanceOf(user.address)).to.equal(BigInt(1));

    // User deposit
    await nftToken.connect(user).approve(await factory.getAddress(), BigInt(0));
    await factory.connect(user).deposit(BigInt(0), [BigInt(0)]);
    userInfo = await factory.userInfo(BigInt(0), user.address);
  });

  it("Check for pending reward", async () => {
    mine(100)

    const userInfo = await factory.userInfo(BigInt(0), user.address);
    expect(userInfo.amount).to.equal(BigInt(1));
    
    const pendingReward = await factory.pendingReward(BigInt(0), user.address);
    expect(pendingReward).to.greaterThan(BigInt(0));
  });

  it("Other users join the pool", async () => {
    await nftToken.connect(owner).mint(await user2.getAddress(), BigInt(1));
    await nftToken.connect(owner).mint(await user3.getAddress(), BigInt(2));

    await nftToken.connect(user2).approve(await factory.getAddress(), BigInt(1));
    await nftToken.connect(user3).approve(await factory.getAddress(), BigInt(2));

    await factory.connect(user2).deposit(BigInt(0), [BigInt(1)]);
    await factory.connect(user3).deposit(BigInt(0), [BigInt(2)]);
  })

  it("Check pending reward for all users", async () => {
    mine(100)

    const pendingReward = await factory.pendingReward(BigInt(0), user.address);
    expect(pendingReward).to.greaterThan(BigInt(0));

    const pendingReward2 = await factory.pendingReward(BigInt(0), user2.address);
    expect(pendingReward2).to.greaterThan(BigInt(0));

    const pendingReward3 = await factory.pendingReward(BigInt(0), user3.address);
    expect(pendingReward3).to.greaterThan(BigInt(0));
  });

  it("Withdraw deposited NFT", async () => {
    await factory.connect(user).withdrawAndHarvest(BigInt(0), [BigInt(0)]);
    expect(await nftToken.balanceOf(user.address)).to.equal(BigInt(1));

    const userTokenIds = await factory.userTokenIds(BigInt(0), user.address);
    expect(userTokenIds.length).to.equal(0);
  })
});
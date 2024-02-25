import { ethers } from "hardhat";
import { SmartBaryFactory, SmartBaryFactory__factory, TestERC20, TestERC20__factory, TestERC721, TestERC721__factory } from "../typechain-types";
import { expect } from "chai";
import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/dist/src/signer-with-address";

describe("Smart Baryon Factory", function () {
  let factory: SmartBaryFactory;
  let ftToken: TestERC20;
  let nftToken: TestERC721;
  let snapshotTime: number;

  let owner: SignerWithAddress;
  let user: SignerWithAddress;

  before(async function () {
    [owner, user] = await ethers.getSigners();

    const BaryonFactory: SmartBaryFactory__factory = await ethers.getContractFactory("SmartBaryFactory");
    factory = await BaryonFactory.connect(owner).deploy();
    await factory.waitForDeployment();

    const ERC20: TestERC20__factory = await ethers.getContractFactory("TestERC20");
    ftToken = await ERC20.connect(owner).deploy(BigInt(1000000000000000000000000));

    const ERC721: TestERC721__factory = await ethers.getContractFactory("TestERC721");
    nftToken = await ERC721.deploy("TestNFT", "TNFT");

    await ftToken.waitForDeployment();
    await nftToken.waitForDeployment();

    snapshotTime = Date.now();
  });

  it("Add new pool", async () => {
    await ftToken.connect(owner).approve(await factory.getAddress(), BigInt(1000000000000000000).toString());

    await factory.connect(owner).addPool(
      [await ftToken.getAddress()],
      [BigInt(1000000).toString()],
      BigInt(snapshotTime),
      BigInt(1000 + snapshotTime),
      BigInt(1000000).toString(),
      await nftToken.getAddress()
    );

    const pool = await factory.getPoolInfo(BigInt(0));
  });

  it("User deposit", async () => {
    // Mint a NFT
    await nftToken.connect(owner).mint(user.address, BigInt(0));
    expect(await nftToken.balanceOf(user.address)).to.equal(BigInt(1));

    // User deposit
    await nftToken.connect(user).approve(await factory.getAddress(), BigInt(0));
    // await factory.connect(user).deposit(BigInt(0), BigInt(1000000000000000000).toString(), BigInt(0));
  });
});

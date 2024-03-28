import { ethers } from "hardhat";
import hre from "hardhat";
import {
  TestERC20,
  SmartBaryFactory,
  // WETH,
  TestERC721,
} from "../../typechain-types";
import { parseEther } from "ethers/lib/utils";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { BigNumberish } from "ethers";

export interface FactoryFixture {
  owner: SignerWithAddress;
  acc1: SignerWithAddress;
  acc2: SignerWithAddress;
  admin: SignerWithAddress;
  accs: SignerWithAddress[];
  smartBaryFactory: SmartBaryFactory;
  usdt: TestERC20;
  usdc: TestERC20;
  starship: TestERC721;
  rewardPerSecond: BigNumberish;
  rewardStartTime: number;
  rewardExpiration: number;
  rewardMultiplierUsdt: BigNumberish;
  rewardMultiplierUsdc: BigNumberish;
}

export async function deployFixture(): Promise<FactoryFixture> {
  const [owner, acc1, acc2, admin, ...accs] = await ethers.getSigners();

  const SmartBaryFactory = await ethers.getContractFactory("SmartBaryFactory");
  const smartBaryFactory = (await SmartBaryFactory.connect(
    owner
  ).deploy()) as SmartBaryFactory;
  await smartBaryFactory.deployed();

  const TestERC20 = await ethers.getContractFactory("TestERC20");

  const usdt = (await TestERC20.connect(owner).deploy(
    parseEther("10000")
  )) as TestERC20;
  const usdc = (await TestERC20.connect(owner).deploy(
    parseEther("10000")
  )) as TestERC20;

  const TestERC721 = await ethers.getContractFactory("TestERC721");
  const starship = (await TestERC721.connect(owner).deploy(
    "Starship",
    "STARSHIP"
  )) as TestERC721;

  await starship.mint(acc1.address, 1);
  await starship.connect(acc1).approve(smartBaryFactory.address, 1);
  await starship.mint(acc2.address, 2);
  await starship.connect(acc2).approve(smartBaryFactory.address, 2);

  await usdt
    .connect(owner)
    .approve(smartBaryFactory.address, parseEther("1000"));

  await usdc
    .connect(owner)
    .approve(smartBaryFactory.address, parseEther("2000"));

  await usdt.deployed();
  await usdc.deployed();
  await starship.deployed();

  const rewardPerSecond = parseEther("10");
  const rewardStartTime = (await time.latest()) + 1000;
  const rewardExpiration = rewardStartTime + 100;
  const rewardMultiplierUsdt = parseEther("1");
  const rewardMultiplierUsdc = parseEther("2");

  return {
    owner,
    acc1,
    acc2,
    admin,
    accs,
    smartBaryFactory,
    usdt,
    usdc,
    starship,
    rewardPerSecond,
    rewardStartTime,
    rewardExpiration,
    rewardMultiplierUsdt,
    rewardMultiplierUsdc,
  };
}

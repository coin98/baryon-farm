// Import the necessary dependencies
import { ZERO_ADDRESS } from "@coin98/solidity-support-library";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import hhe from "hardhat";
import { SmartBaryFactory } from "../typechain-types";

describe("Baryon Factory", async function () {
  let owner: Signer;
  let ownerAddress: string;
  let sender: Signer;
  let senderAddress: string;
  let recipient: Signer;
  let recipientAddress: string;
  let baryonFactory: SmartBaryFactory;
  let maxSupply = 1_000_000_000;
  let minFee = hhe.ethers.utils.parseEther("1");
  let priceN = BigNumber.from("1");
  let priceD = BigNumber.from("100");
  let snapshot: any;

  before(async function () {
    [owner, sender, recipient] = await hhe.ethers.getSigners();
    ownerAddress = await owner.getAddress();
    senderAddress = await sender.getAddress();
    recipientAddress = await recipient.getAddress();
    const baryonFactoryContract = await hhe.ethers.getContractFactory(
      "SmartBaryFactory"
    );
    baryonFactory = await baryonFactoryContract
      .connect(owner)
      .deploy("SmartBaryFactory", "SBF", 18);
    await baryonFactory.deployed();
  });

  beforeEach(async function () {
    snapshot = await hhe.ethers.provider.send("evm_snapshot", []);
  });

  afterEach(async function () {
    await hhe.ethers.provider.send("evm_revert", [snapshot]);
  });

  it("check ownership", async function () {
    expect(await baryonFactory.operator()).to.equal(ownerAddress);
  });
});

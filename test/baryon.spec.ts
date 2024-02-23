import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Smart Baryon Factory", function () {

  before(async function() {
    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
    this.user1 = this.signers[1];
  })
  
});

import {
  BigNumber,
  Signer
} from 'ethers';
import hhe from 'hardhat';
import {
  SmartBaryFactory,
  WVIC
} from '../typechain-types';
import {
  time } from '@nomicfoundation/hardhat-network-helpers';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

describe('SmartBaryFactory NativeToken tests', async function() {
  let owner: Signer;
  let ownerAddress: string;
  let user: Signer;
  let userAddress: string;
  let wvicToken: WVIC;
  let sut: SmartBaryFactory;
  let snapshot: any;

  before(async function() {
    [owner, user] = await hhe.ethers.getSigners();
    ownerAddress = await owner.getAddress();
    userAddress = await user.getAddress();
    const wvicTokenFactory = await hhe.ethers.getContractFactory('WVIC');
    wvicToken = await wvicTokenFactory.connect(owner).deploy();
    await wvicToken.deployed();
    const sutFactory = await hhe.ethers.getContractFactory('SmartBaryFactory');
    sut = await sutFactory.connect(owner).deploy(wvicToken.address, 'BaryonFarm', 'BFT', 18);
    await sut.deployed();
  });

  beforeEach(async function() {
    snapshot = await hhe.ethers.provider.send('evm_snapshot', []);
  });

  afterEach(async function() {
    await hhe.ethers.provider.send('evm_revert', [snapshot]);
  });

  // it('owner should create single pool successful', async function() {
  //   const currentTimestamp = Math.round(new Date().getTime() / 1000);
  //   await wvicToken.connect(owner).deposit({ value: hhe.ethers.utils.parseEther('1')});
  //   await sut.connect(owner).addPool(
  //     [wvicToken.address],
  //     [hhe.ethers.utils.parseUnits('1', 18)],
  //     currentTimestamp,
  //     currentTimestamp + 86400,
  //     hhe.ethers.utils.parseUnits('1', 0),
  //     wvicToken.address,
  //   );
  // });

  it('user should do emergency withdraw successful', async function() {
    const currentTimestamp = Math.round(new Date().getTime() / 1000);
    await wvicToken.connect(owner).deposit({ value: hhe.ethers.utils.parseEther('1')});
    await wvicToken.connect(owner).approve(sut.address, hhe.ethers.utils.parseEther('1'));
    await sut.connect(owner).addPool(
      [wvicToken.address],
      [hhe.ethers.utils.parseUnits('1', 1)],
      currentTimestamp,
      currentTimestamp + 86400,
      hhe.ethers.utils.parseUnits('1', 18),
      wvicToken.address,
    );
    await sut.connect(user).deposit(BigNumber.from(0), hhe.ethers.utils.parseEther('1'), { value: hhe.ethers.utils.parseEther('1')});
    await time.increase(3600);
    await sut.connect(user).emergencyWithdraw(BigNumber.from(0));
  });
});

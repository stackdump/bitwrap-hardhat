const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
require("@nomiclabs/hardhat-web3");
const { ethers } = require("hardhat");
const web3 = require("web3");

describe("Metamodel", function () {
  async function deployTestProxy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, p0, p1] = await ethers.getSigners();

    const contract = await ethers.getContractFactory("contracts/Metamodel.sol:TicTacToe");
    const api = await contract.deploy(p0.address, p1.address); // REVIEW: swap to test access ctl
    // console.log(api.from);

    return { contract, api, p0, p1 };
  }

  describe("Deployment", function () {

    it("should allow gameplay", async function () {
      const { api , p0, p1} = await loadFixture(deployTestProxy);
      // console.log({api})
      const x = await api.connect(p0);
      const o = await api.connect(p1);

      await x.X11();
      await o.O01();
      await x.X00();
      await o.O02();
      await x.X22(); // X wins

      await o.turnTest();
      await x.resetX();
      await x.turnTest();

      await x.X11();
      await o.O01();
      await x.X00();
      await o.O02();
      await x.X22(); // X wins
    });

  });
});

import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

describe("Dropless", function () {
  it("Test contract", async function () {
    const ContractFactory = await ethers.getContractFactory("Dropless");

    const instance = await upgrades.deployProxy(ContractFactory);
    await instance.deployed();

    expect(await instance.name()).to.equal("Dropless");
  });
});

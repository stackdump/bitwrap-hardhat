// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const unlockTime = currentTimestampInSeconds + 60;
  // const lockedAmount = hre.ethers.utils.parseEther("0.001");


  const me = "0xd20F93E2D8f7378946E8642F7579723B9A81544A"
  const ze = "0xCae1d2Aa66E01daCf90a655519099620cbf85B72"
    
  async function deploy(name) {
    const mm = await hre.ethers.getContractFactory(name);
    const model = await mm.deploy(me, ze)
    await model.deployed();

    console.log( `${name} deployed to ${model.address}` );
  }

  // await deploy("MetamodelUint8")
  // await deploy("TicTacToeModel")
  await deploy("TicTacToe")

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

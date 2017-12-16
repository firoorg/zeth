var BigNumberLib = artifacts.require("./BigNumberLib.sol");

module.exports = function(deployer) {
  deployer.deploy(BigNumberLib);
};
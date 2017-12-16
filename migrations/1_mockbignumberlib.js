var MockBigNumberLib = artifacts.require("./MockBigNumberLib.sol");

module.exports = function(deployer) {
  deployer.deploy(MockBigNumberLib);
};
var BigNumberLib = artifacts.require("BigNumberLib");
//var Zerocoin = artifacts.require("Zerocoin");

module.exports = function(deployer) {
  deployer.deploy(BigNumberLib);
  //deployer.link(BigNumberLib, Zerocoin);
  //deployer.deploy(Zerocoin);
};
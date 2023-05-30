// migrating the appropriate contracts
var Spectrum = artifacts.require("./Spectrum.sol");

module.exports = function(deployer) {
  deployer.deploy(Spectrum);
};
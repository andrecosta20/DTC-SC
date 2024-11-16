const CDSC = artifacts.require("CDSC");
const DTSC = artifacts.require("DTSC");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(CDSC, accounts[0], accounts[1], accounts[2]); 
  deployer.deploy(DTSC, accounts[2], accounts[1], accounts[0]); 
};

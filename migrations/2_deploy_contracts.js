const CDSC = artifacts.require("CDSC");
const DTSC = artifacts.require("DTSC");

module.exports = function (deployer) {
    deployer.deploy(CDSC);
    deployer.deploy(DTSC);
};

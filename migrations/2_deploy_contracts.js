var Shopfront = artifacts.require("./Shopfront.sol");
var HumanStandardToken = artifacts.require("./HumanStandardToken.sol");

var fee = 1;

var initialAmount = 1000;
var tokenName = "Shopfront Token";
var decimalUnits = 8;
var tokenSymbol = "TNK";

module.exports = function(deployer) {
  deployer.deploy(Shopfront, fee);

  console.log("Shopfront merchant fee = "+fee);

  deployer.deploy(HumanStandardToken, initialAmount, tokenName, decimalUnits, tokenSymbol);

  console.log("Shopfront Token deployed: initial amount = "+initialAmount+", token name = '"+tokenName+"', decimal units = "+decimalUnits+", symbol = '"+tokenSymbol+"'");
};

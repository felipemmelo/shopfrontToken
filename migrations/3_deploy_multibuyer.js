var Shopfront = artifacts.require("Shopfront");
var MultiBuyerCollector = artifacts.require("./MultiBuyerCollector.sol");


module.exports = function(deployer) {

  Shopfront.deployed().then(instance => {

  	deployer.deploy(MultiBuyerCollector, instance.address);

  	console.log("MultiBuyerCollector deployed for Shopfront at "+instance.address);
  });
};

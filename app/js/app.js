require("file-loader?name=../index.html!../index.html");

const Web3 = require("web3");
const Promise = require("bluebird");
const truffleContract = require("truffle-contract");
const $ = require("jquery");
// Not to forget our built contract
const shopfrontJson = require("../../build/contracts/Shopfront.json");

window.web3 = new Web3(new Web3.providers.HttpProvider('http://localhost:8545'));

Promise.promisifyAll(web3.eth, { suffix: "Promise" });
Promise.promisifyAll(web3.version, { suffix: "Promise" });

window.Shopfront = truffleContract(shopfrontJson);
Shopfront.setProvider(web3.currentProvider);

/*
window.addEventListener('load', function() {
    return web3.eth.getAccountsPromise()
        .then(accounts => {
            if (accounts.length == 0) {
                $("#balance").html("N/A");
                throw new Error("No account with which to transact");
            }
            window.account = accounts[0];
            return Shopfront.deployed();
        })
        .then(deployed => deployed.getCurrentFunds.call({from: window.account}))
        .then(balance => $("#balance").html(balance.toString(10)))
        .catch(console.error);
});
*/
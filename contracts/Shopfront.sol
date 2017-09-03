pragma solidity ^0.4.10;

/**
 * Provides safe algebraic methods which prevent wrap around errors.
 */ 
contract SafeMath  {
  uint256 constant public MAX_UINT256 =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  function safeAdd (uint256 x, uint256 y)
  constant internal
  returns (uint256 z) {
    if (x > MAX_UINT256 - y) revert();
    return x + y;
  }

  function safeSub (uint256 x, uint256 y)
  constant internal
  returns (uint256 z) {
    if (x < y) revert();
    return x - y;
  }

  function safeMul (uint256 x, uint256 y)
  constant internal
  returns (uint256 z) {
    if (y == 0) return 0;
    if (x > MAX_UINT256 / y) revert();
    return x * y;
  }
}


/**
 * Base for the Shop contracts which are now capable of receiving tokens funds.
 */
contract ERC20Extension {
    
    function receiveApproval(address _from, uint256 _value, address _tokenContract, bytes32 _extraData);
}

/**
 * Base for contracts that provided special access to their owners.
 */ 
contract Owned {
    
    address public owner;
    
    function Owned() {
        owner = msg.sender;
    }
    
    modifier isOwner {
        require(msg.sender == owner);
        _;
    }    
}

/**
 * Base for contracts that work with the abstraction of multiple merchants.
 */ 
contract MerchantsManager is Owned {
    
    mapping(address => bool) public admins;    
    mapping(address => uint) public merchantsBalances;      
    
    modifier isMerchantAdmin(address admin) {
        require(admins[admin]);
        _;
    }       
    
    // Adds a verified merchant administrator, can have n
    function addMerchantAdmin(address admin) 
    isOwner
    external 
    returns (bool)
    {     
        admins[admin] = true;   
        return true;
    }    
    
    // withdraw funds on behalf of a merchant
    function withdraw() 
    isMerchantAdmin(msg.sender)
    external
    returns(uint)
    {
        uint merchantTotalBalance = merchantsBalances[msg.sender];
        
        // checks if the contract has enough funds to transfer to the merchant
        assert(this.balance >= merchantTotalBalance);
        
        // decreased first in order to avoid reentrancy attacks
        merchantsBalances[msg.sender] = 0;

        msg.sender.transfer(merchantTotalBalance);
    }     
}

/**
 * 
 * Implements a multi-merchant and multi-token shopfront.
 * 
 */ 
contract Shopfront is SafeMath,ERC20Extension,MerchantsManager {

    event LogPurchase(address indexed buyer, bytes32 indexed product, bool indexed token);

    event LogOutOfStock(bytes indexed product);        

    struct Product {
        uint price;
        uint stock;
        address merchant;
    }    
    
    mapping(bytes32 => Product) public products;
    
    mapping(address => bool) acceptedTokens;    
    mapping(address => uint) public tokensBalances;    

    mapping(uint => bytes32) public multibyersPurchases;
    
    uint public fee;
    
    function Shopfront(uint _fee) {
        fee = _fee;    
        admins[msg.sender] = true;
    }    

    modifier isProductOwner(address merchant, bytes32 productId) {
        require(products[productId].merchant == merchant);
        _;
    }    
    
    modifier validPrice(uint price) {
        require(price > fee);
        _;
    }    
    
    modifier productInStock(bytes32 productId) {
        require(products[productId].stock > 0);
        _;
    }
    
    modifier purchaseValueIsCorrect(bytes32 productId, uint value) {
        require(value == products[productId].price);
        _;
    }
    
    modifier tokenIsAccepted(address token) {
        require(acceptedTokens[token]);
        _;
    }
    
    modifier idIsAvailable(bytes32 productId) {
        require(products[productId].price == 0);
        _;
    }

    //The shop can work with multiple tokens
    function addAcceptedToken(address token)
    isOwner
    returns(bool)
    {
        acceptedTokens[token] = true;
        return true;
    } 
    
    function removeAcceptedToken(address token)
    isOwner
    returns(bool)
    {
        acceptedTokens[token] = false;
    }    
    
    function getProductData(bytes32 productId) 
    constant
    external
    returns(uint price, uint stock, address merchant) 
    {
        Product storage product = products[productId];

        price = product.price;
        stock = product.stock;
        merchant = product.merchant;        
    }    
    
    function getProductMerchant(bytes32 productId)
    internal
    constant
    returns(address)
    {
        return products[productId].merchant;
    }
    
    // adds/updates a product 
    function addProduct(bytes32 id, uint price, uint stock) 
    idIsAvailable(id)
    isMerchantAdmin(msg.sender) 
    validPrice(price)     
    external 
    returns(bool)
    {
        products[id] = Product(price, stock, msg.sender);

        return true;
    }

    // adds/updates a product 
    function updateProduct(bytes32 id, uint price, uint stock)     
    isProductOwner(msg.sender, id)
    validPrice(price) 
    external 
    returns(bool)
    {
        products[id] = Product(price, stock, msg.sender);
        return true;
    }
    
    // removes a product
    function removeProduct(bytes32 productId) 
    external 
    isProductOwner(msg.sender, productId)
    returns(bool) 
    {
        products[productId] = Product(0x0, 0x0, 0x0);
        return true;
    }    

    // concludes a purchase by changing balances and stocks and logging the purchase
    function concludePurchase(bytes32 productId, uint value, address buyer, bool fromToken)     
    internal
    {
        Product storage product = products[productId];

        product.stock--;

        merchantsBalances[product.merchant] = safeAdd(merchantsBalances[product.merchant], value - fee);
        
        // notifies about a new purchase
        LogPurchase(buyer, productId, fromToken);        
    }

    // allows a user to buy a product with ether
    function buy(bytes32 productId) 
    productInStock(productId)
    purchaseValueIsCorrect(productId, msg.value)
    payable
    external 
    returns(bool)
    {
        concludePurchase(productId, msg.value, msg.sender, false);

        return true;
    }
    
    // allows a multi-buyer purchase
    // this function is expected to be called by the MultiBuyerCollector contract.
    function multibuy(bytes32 productId, uint purchaseId) 
    productInStock(productId)
    purchaseValueIsCorrect(productId, msg.value)
    payable
    external 
    returns(bool)
    {
        multibyersPurchases[purchaseId] = productId;        

        concludePurchase(productId, msg.value, msg.sender, false);

        return true;
    }

    // allows a user to buy products with a token, as long as the token is accepted by this shop
    // this function is expected to be called by tokens accepted by this contract
    function receiveApproval(address _from, uint256 _value, address _tokenContract, bytes32 _productId)
    tokenIsAccepted(msg.sender)
    productInStock(_productId)
    purchaseValueIsCorrect(_productId, _value)
    {
        require(_tokenContract.call(bytes4(sha3("transferFrom(address,address,uint256)")), _from, this, _value));        
        
        tokensBalances[_tokenContract] = safeAdd(tokensBalances[_tokenContract], _value);

        concludePurchase(_productId, _value, _from, true);       
    }     
}

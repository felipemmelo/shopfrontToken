pragma solidity ^0.4.10;

import "./Shopfront.sol";

/*
 This contract implements the gatherer to allow purchases to be done
 by multiple buyers at the same time.

 The rationale is:

 1. The purchase owner initiates the purchase by calling "signalPurchase", specifying the id
    of the product being bought and also sending some ether, whose amount has to be <= than
    the product price.

    This method returns how much is still missing to finish the purchase and the purchase id,
    which will be used by the other users to refer to the initiated co-purchase.

2. The other buyers can send funds by calling "continuePurchase" and referring to the purchase id.
   Again, the current ethers sent plus the previous gathered fund cannot be greater than the produce price.

3. If, during the execution of "continuePurchase" the required funds are reached, the purchase is attempted
   by calling the appropriate function on the Shopfront contract. 

   In case of success, the purchase is finalized, otherwise, the current value of the missing funds is returned, 
   which will be zero, which will tell the caller that the product price was reached, thus, the method can be
   called again in case it failed.

   The purchase id is also stored in the Shopfront, which allows for further verification.

4. The purchase starter may also terminate the purchase if it hasn't been completed yet. 

5. The co-buyers can reclaim unused funds in two situations: a) if the purchase is already open, and b) if closed
by the owner without being finished.

 */
contract MultiBuyerCollector is SafeMath {
    
    event LogNewPurchase(bytes32 indexed productId, address indexed buyer, uint indexed purchaseId);
    event LogNewFunds(uint indexed purchaseId, address indexed buyer, uint indexed amount);
    event LogFundsReclaimed(uint indexed purchaseId, address indexed claimant, uint amount);
    event LogPurchaseCanceled(uint indexed purchaseId);
    
    Shopfront shopfront;
    
    struct Purchase {
        bytes32 productId;
        uint price;
        uint gatheredFunds;
        bool open;
        address owner;
        bool closedByOwner;
    }
    
    mapping(uint => Purchase) purchaseFunds;
    mapping(uint => mapping(address => uint)) purchaseParticipants;
    
    uint purchaseIdGenerator;
    
    function MultiBuyerCollector(address _shopfrontAddress) {
        shopfront = Shopfront(_shopfrontAddress);
        purchaseIdGenerator = 0;
    }
    
    modifier validFunds(uint funds) {
        require(funds > 0);
        _;
    }
    
    modifier isOpen(uint purchaseId) {
        require(purchaseFunds[purchaseId].open);
        _;
    }
    
    modifier buyerHasFundsToReclaim(uint purchaseId, address buyer) {
        require(purchaseParticipants[purchaseId][buyer] > 0);
        _;
    }
    
    modifier isPurchaseOwner(uint purchaseId, address sender) {
        require(purchaseFunds[purchaseId].owner == sender);
        _;
    }
    
    modifier openOrClosedByOwner(uint purchaseId) {
        require(purchaseFunds[purchaseId].open || purchaseFunds[purchaseId].closedByOwner);
        _;        
    }
    
    function signalPurchase(bytes32 productId) 
    payable
    validFunds(msg.value)
    external
    returns (uint purchaseId, uint missingFunds)
    {
        uint price;

        (price, , ) = shopfront.getProductData(productId);   
        
        assert(price > 0);
        assert(msg.value <= price);
        
        missingFunds = safeSub(price, msg.value);
        
        purchaseId = purchaseIdGenerator++;
        
        purchaseFunds[purchaseId] = Purchase(productId, price, msg.value, true, msg.sender, false);
        
        purchaseParticipants[purchaseId][msg.sender] = safeAdd(purchaseParticipants[purchaseId][msg.sender], msg.value);
        
        LogNewPurchase(productId, msg.sender, purchaseId);
    }    
    
    function continuePurchase(uint purchaseId) 
    payable
    isOpen(purchaseId)
    external
    returns(uint missingFunds, bool success)
    {
        Purchase storage purchase = purchaseFunds[purchaseId];
        
        purchase.gatheredFunds += msg.value;
        
        assert(purchase.gatheredFunds <= purchase.price);
        
        purchaseParticipants[purchaseId][msg.sender] = safeAdd(purchaseParticipants[purchaseId][msg.sender], msg.value);
        
        missingFunds = safeSub(purchase.price, purchase.gatheredFunds);
        
        LogNewFunds(purchaseId, msg.sender, msg.value);
        
        if (missingFunds == 0) {
            
            if (shopfront.buy.value(purchase.price)(purchase.productId)) {
                
                purchase.open = false;   
                
                success = true;
            }
        }
    }
    
    function reclaimUnusedFunds(uint purchaseId)
    openOrClosedByOwner(purchaseId)
    buyerHasFundsToReclaim(purchaseId, msg.sender)
    external
    returns(bool success, uint missingFunds)
    {
        uint reclaimedFunds = purchaseParticipants[purchaseId][msg.sender];
        
        purchaseParticipants[purchaseId][msg.sender] = 0;
        
        Purchase storage purchase = purchaseFunds[purchaseId];
        
        purchase.gatheredFunds = safeSub(purchase.gatheredFunds, reclaimedFunds);
        
        msg.sender.transfer(reclaimedFunds);
        
        LogFundsReclaimed(purchaseId, msg.sender, reclaimedFunds);
        
        success = true;
        missingFunds = purchase.price - purchase.gatheredFunds;
    }
    
    function closePurchase(uint purchaseId)
    isPurchaseOwner(purchaseId, msg.sender)
    isOpen(purchaseId)
    returns(bool)
    {
        Purchase storage purchase = purchaseFunds[purchaseId];
        purchase.open = false;
        purchase.closedByOwner = true;
        
        return true;
    }
}








// SPDX-License-Identifier: MIT

pragma solidity >=0.8.13 <0.9.0;

    /// @title Smart Contract for Food Delivery Application
    /// @author Jaikarthik Natarajan (Bits Id: 2020mt93717@wilp.bits-pilani.ac.in)
    /// @author Salil Mohan (Bits Id: 2020MT93522@wilp.bits-pilani.ac.in)
    /**
       -------------------------- // -------------------------- // --------------------------
                                      FoodDeliveryContract
       -------------------------- // -------------------------- // --------------------------

       1. Order is created in NEW State.
          a. It's mandatory to have restaurant address, customer address, platform address, delivery charges
             Platform charges and Order Items when Creating the order. 

       2. Order Moves to CUSTOMER_PAID state when customer deposits fund greater than 
          total amount (Order Value + Delivery Charge + Platform Charge). This is applicable only for new Orders.
          Only Customer Can do this. Smart Contract Will does not accept payment from any other account.
         
       3. Customer needs to deposit amount before restaurant accepts the order with RESTAURANT_PREPARING state.  
          Only customer can fun the order. Funcing will fail if anyother account transfer funds to this contract.

       4. Only the restaurant can acknowledge an Order which is in the CUSTOMER_PAID state. Acknowledging order will move 
          the order to RESTAURANT_PREPARING state. Contract will not allow anyone else to do this.

       5. Only the Customer or Restaurant can cancel the order. And they can only cancel when the order is in specific states.
          When successful the order moves to ORDER_CANCELLED state. No other action is possible on ORDER_CANCELLED orders.
          Smart Contract will not allow anyone else to cancel the order.
       
       6. Customer Can cancel the order only when the order is in a NEW or CUSTOMER_PAID state. 
          Customer cannot cancel an order once the order moves to other state. 

       7. Restaurant can only cancel the order in NEW, CUSTOMER_PAID, or RESTAURANT_PREPARING States.
          Restaurant cannot cancel an order once the order moves to other state.
          
       8. When the Customer or Restaurant cancels the Order, the amount deposited by the Customer is refunded to the customer.
       
       9. No further actions are possible on ORDER_CANCELLED orders.

       8. Only the Delivery platform can assign or reassign Delivery Partner only when the Order is in NEW, CUSTOMER_PAID, or RESTAURANT_PREPARING states.

      10. Only the Delivery partner can accept the order items from the restaurant and only when the Order state is in RESTAURANT_PREPARING. 
          During this step, the delivery partner must list out the items received from the restaurant. This is compared with the order items and 
            a. If there are missing items in the order, then the order moves to HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS state
            b. If there are No missing items in the order, the order moves to HANDED_OVER_TO_DELIVERY_PARTNER state

      11. If the Order is in HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS, the Restaurant needs to confirm that the items are missing.
          Missing item price is reduced from the order value. After this, the Order state is moved to HANDED_OVER_TO_DELIVERY_PARTNER. 
          We should not allow anyone other than the restaurant to confirm the missing items.

      12. Only Customer can only accept order and only when the order state is in HANDED_OVER_TO_DELIVERY_PARTNER. When customre accepts the order
            a. Order Value is transfered to the restaurant
            b. Delivery Charge is transfered to Delivery partner
            c. Platform Charges is transfered to Platform
            d. Balance is transfered back to Customer
          Order State is moved to DELIVERED_TO_CUSTOMER. 

      13. No Further action is possible on Order which is in DELIVERED_TO_CUSTOMER state.
          
    */

contract FoodDeliveryContract {


    /// @dev All Applicable Order Status
    enum OrderStatus{ NEW, CUSTOMER_PAID, RESTAURANT_PREPARING, HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS, HANDED_OVER_TO_DELIVERY_PARTNER, DELIVERED_TO_CUSTOMER, ORDER_CANCELLED }

    /// @dev Order Item Definition
    struct OrderItem {
        uint8 itemId;
        string itemName;
        uint itemPrice;
    }

    /// @dev Order Item array
    OrderItem[] _orderItems;

    /// @dev Number of Items in the Order
    uint _numberOfItems;

    /// @dev Address of Platform. Platform Charges will be transfered to this address
    address payable _platformAddress;

    /// @dev Address of Restaurant. Order Value will be transfered to this address
    address payable _restaurantAddress;

    /// @dev Address of Delivery Partner. Delivery Charges will be transfered to this address
    address payable _deliveryPartnerAddress;

    /// @dev Address of Customer. Balance/Cancellation/Refund amount will be transfered to this address. 
    address payable _customerAddress;      

    /// @dev Current Order Status
    OrderStatus _orderStatus;

    /// @dev Order Value. This is sum of all Order Item price
    uint _orderValue;

    /// @dev Delivery Charges. This will be paid to Delivery parther once Order is delivered
    uint _orderDeliveryCharge;

    /// @dev Platform Charges. This will be paid to Platform once Order is delivered
    uint _platformCharge;

    /// @dev Escarow Amount that was transfered by Customer to this Contract
    uint _customerEscarowAmount;

    /// @dev Missing Order Items
    uint[] _missingOrderItems;

    /// @notice Contract Constructor
    /// @param restaurantAddress Address of Restaurant. Order Value will be transfered to this address
    /// @param deliveryPartnerAddress Address of Delivery Partner. Delivery Charges will be transfered to this address
    /// @param customerAddress Address of Customer. Balance/Cancellation/Refund amount will be transfered to this address. 
    /// @param platformAddress Address of Platform. Platform Charges will be transfered to this address
    /// @param orderItems Order Item for this Order
    /// @param orderDeliveryCharge Delivery Charges. This will be paid to Delivery parther once Order is delivered
    /// @param platformCharge Platform Charges. This will be paid to Platform once Order is delivered
    constructor (address payable restaurantAddress, address payable deliveryPartnerAddress, address payable customerAddress, address payable platformAddress, OrderItem[] memory orderItems
                    , uint orderDeliveryCharge, uint platformCharge) {
        
        require(restaurantAddress != address(0), "Restaurant Address is required");
        require(customerAddress != address(0), "Customer Address is required");
        require(platformAddress != address(0), "Platform Address is required");
        require(orderDeliveryCharge > 0, "Delivery Charges Should be Greater than 0");
        require(platformCharge > 0, "Platform Charges Should be Greater than 0");


        _platformAddress = platformAddress;
        _restaurantAddress = restaurantAddress;
        _deliveryPartnerAddress = deliveryPartnerAddress;
        _customerAddress = customerAddress;
        _orderStatus = OrderStatus.NEW;
        _numberOfItems = orderItems.length;

        for (uint i=0; i<_numberOfItems; i++) {
            _orderItems.push(orderItems[i]);
            _orderValue += orderItems[i].itemPrice; 
            _missingOrderItems.push(orderItems[i].itemId);
            // Validate Duplicate ItemId 
        }
        _orderDeliveryCharge = orderDeliveryCharge;
        _platformCharge = platformCharge;  
    }

    /// @dev Modifier that checks if the Invoker is Customer.
    modifier onlyCustomer {
        //is the customer the message sender
        require(msg.sender == _customerAddress, "Only Customer can Call this");
        _;                            
    }

    /// @dev Modifier that checks if the Invoker is Restaurant.
    modifier onlyRestaurant {
        //is the restaurant the message sender
        require(msg.sender == _restaurantAddress, "Only Restaurant can Call this");
        _;                            
    }

    /// @dev Modifier that checks if the Invoker is Delivery Partner.
    modifier onlyDeliveryPartner {
        //is the restaurant the message sender
        require(msg.sender == _deliveryPartnerAddress, "Only Delivery Partner can Call this");
        _;                            
    }

    /// @dev Modifier that checks if the Invoker is Delivery Platform.
    modifier onlyDeliveryPlatform {
        //is the restaurant the message sender
        require(msg.sender == _platformAddress, "Only Delivery Platform can Call this");
        _;                            
    }

    /// @dev Modifier that checks if the order is in NEW State.
    modifier onlyNewOrder {
        require(_orderStatus == OrderStatus.NEW);
        _;                            
    }

    /// @dev Modifier that checks if the order is in NEW State.
    modifier onlyCustomerPaidOrder {
        require(_orderStatus == OrderStatus.CUSTOMER_PAID);
        _;                            
    }

    /// @dev Modifier that checks if the order is in NRESTAURANT_PREPARING State.
    modifier onlyRestaurantPreparingOrder {
        require(_orderStatus == OrderStatus.RESTAURANT_PREPARING);
        _;                            
    }

    /// @dev Modifier that checks if the order is in HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS State.
    modifier onlyHandedToDeliveryPartnerWithMissingItemsOrder {
        require(_orderStatus == OrderStatus.HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS);
        _;                            
    }

    /// @dev Modifier that checks if the order is in HANDED_OVER_TO_DELIVERY_PARTNER State.
    modifier onlyHandedToDeliveryPartnerOrder {
        require(_orderStatus == OrderStatus.HANDED_OVER_TO_DELIVERY_PARTNER);
        _;                            
    }

    /// @dev Modifier that checks if Delivery Partner Address is Valid.
    modifier onlyAfterDeliveryPartnerIsAssigned {
        require(_deliveryPartnerAddress != address(0));
        _;                            
    }

    /// @notice Get Order Value. This is the amount to be paid to Restaurant once order is delivered to customer.
    /// @return Order Values in wei
    function getOrderValue() view public returns (uint) {
        return _orderValue;   
    }

    /// @notice Get Delivery Charge. This is the amount to be paid to Delivery Partner once order is delivered to customer.
    /// @return Delivery Charge in wei
    function getOrderDeliveryCharge() view public returns (uint) {
        return _orderDeliveryCharge;   
    }

    /// @notice Get Platform Charge. This is the amount to be paid to Delivery Platform once order is delivered to customer.
    /// @return Platform Charge in wei
    function getPlatformCharge() view public returns (uint) {
        return _platformCharge;   
    }

    /// @notice Total Order Value. This is the value of this contract. Its the sum of 
    ///.        Delivery Charge + Order Value + Platform Charge.
    /// @dev Customer Escarow amount should be greater or equal to this value
    /// @return Total Orver Value in wei
    function getTotalOrderValue() view public returns (uint) {
        return _orderValue + _orderDeliveryCharge + _platformCharge;   
    }

    /// @notice Get Order State
    /// @return Order State
    function getOrderState() view public returns (OrderStatus) {
        return _orderStatus;
    }

    /// @notice Order Items that are part of this order.
    /// @return Order Items 
    function getOrderItems() view public returns (OrderItem[] memory) {
        OrderItem[] memory orderItems = new OrderItem[](_numberOfItems);
        for (uint i = 0; i < _numberOfItems; i++) {
            if(_orderStatus == OrderStatus.NEW || _orderStatus == OrderStatus.CUSTOMER_PAID || _orderStatus == OrderStatus.RESTAURANT_PREPARING
                    || find(_missingOrderItems, orderItems[i].itemId) == -1 ) {
                OrderItem storage orderItem = _orderItems[i];
                orderItems[i] = orderItem;
            }
        }
        return orderItems;  
    }

    /// @notice Assign or Update Delivery Partner. Can be done only by Delivery Platform.
    ///    This action can be performed only when the order is in NEW or CUSTOMER_PAID or RESTAURANT_PREPARING State
    function assignDeliverPartnerAddress(address payable deliveryPartnerAddress) onlyDeliveryPlatform public {
        require ((_orderStatus == OrderStatus.NEW || _orderStatus == OrderStatus.CUSTOMER_PAID || _orderStatus == OrderStatus.RESTAURANT_PREPARING),
                        "Cannot Assign New Delivery Partner after the Order is already handed over to Delivery Partner");
        _deliveryPartnerAddress = deliveryPartnerAddress;
    }

    /// @notice Only the Customer or Restaurant can cancel the order. And they can only cancel when the order is in specific states.
    /// When successful the order moves to ORDER_CANCELLED state. This will not allow anyone else to cancel the order.
    /// Customer Can cancel the order only when the order is in a NEW or CUSTOMER_PAID state. 
    /// Customer cannot cancel an order once the order moves to other state. 
    /// Restaurant can only cancel the order in NEW, CUSTOMER_PAID, or RESTAURANT_PREPARING States.
    /// Restaurant cannot cancel an order once the order moves to other state.
    function cancelOrder() payable public {

        require ((_customerAddress == msg.sender || _restaurantAddress == msg.sender), 
                "Only Customer or Restaurant Can Cancel the order");
        if((_customerAddress == msg.sender)) {
            require((_orderStatus == OrderStatus.NEW || _orderStatus == OrderStatus.CUSTOMER_PAID), 
                        "Customer Cannot Cancel Order once restaurant starts preparing the order");
        }
        if((_restaurantAddress == msg.sender)) {
            require((_orderStatus == OrderStatus.NEW || _orderStatus == OrderStatus.CUSTOMER_PAID || _orderStatus == OrderStatus.RESTAURANT_PREPARING), 
                        "Restaurant Cannot Cancel Order once the Order is handed over to delivery Partner");
        }
        // transfer customer paid amount back to customer
        _customerAddress.transfer(address(this).balance);
        // Set Current Escarow Amount to 0
        _customerEscarowAmount = 0;
        // Updated Order Status to Cancelled
        _orderStatus = OrderStatus.ORDER_CANCELLED;
    }

    /// @notice Customer needs to deposit amount before restaurant accepts the order with RESTAURANT_PREPARING state. 
    ///. Only customer can fun the order. Funcing will fail if anyother account transfer funds to this contract.
    function payOrder() onlyNewOrder onlyCustomer public payable {
        uint totalOrderValue = _orderValue + _orderDeliveryCharge + _platformCharge;        
        require(msg.value >= totalOrderValue, "You need to spend more than Total Order Value");
        _customerEscarowAmount += msg.value;
        _orderStatus = OrderStatus.CUSTOMER_PAID;
    }
    /// @notice Only the restaurant can acknowledge an Order which is in the CUSTOMER_PAID state. Acknowledging order will move 
    /// the order to RESTAURANT_PREPARING state. Contract will not allow anyone else to do this.
    function restaurantAcknolegement() onlyCustomerPaidOrder onlyRestaurant  public {
        _orderStatus = OrderStatus.RESTAURANT_PREPARING;
    }

    /// @notice Only the Delivery partner can accept the order items from the restaurant and only when the Order state is in RESTAURANT_PREPARING. 
    ///   During this step, the delivery partner must list out the items received from the restaurant. This is compared with the order items and 
    ///     a. If there are missing items in the order, then the order moves to HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS state
    ///     b. If there are No missing items in the order, the order moves to HANDED_OVER_TO_DELIVERY_PARTNER state
    /// @param recievedOrderItemIds items received from the restaurant
   function deliveryPartnerAcceptsOrder(uint[] memory recievedOrderItemIds) onlyRestaurantPreparingOrder onlyAfterDeliveryPartnerIsAssigned onlyDeliveryPartner public  {
        for (uint i = 0; i < recievedOrderItemIds.length; i++) {
            removeByValue(_missingOrderItems, recievedOrderItemIds[i]);
        }
        if(_missingOrderItems.length == 0) {
            _orderStatus = OrderStatus.HANDED_OVER_TO_DELIVERY_PARTNER;
        } else {
            _orderStatus = OrderStatus.HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS;
        }
   }

    /// @notice Get Missing Order Items that are part of this order.
    /// @return Missing Order Items 
   function getMissingOrderItems() view public returns (OrderItem[] memory) {
        OrderItem[] memory orderItems = new OrderItem[](_numberOfItems);
        for (uint i = 0; i < _numberOfItems; i++) {
            if(_orderStatus != OrderStatus.NEW && _orderStatus == OrderStatus.CUSTOMER_PAID && _orderStatus == OrderStatus.RESTAURANT_PREPARING
                    && find(_missingOrderItems, orderItems[i].itemId) != -1 ) {
                OrderItem storage orderItem = _orderItems[i];
                orderItems[i] = orderItem;
            }
        }
        return orderItems;
   }

    /// @notice This can only be called by restaurant and only if the order stat is in HANDED_OVER_TO_DELIVERY_PARTNER_MISSING_ITEMS. 
    /// The Restaurant needs to confirm that the items are missing. Missing item price is reduced from the order value.
    /// After this, the Order state is moved to HANDED_OVER_TO_DELIVERY_PARTNER. 
    function restaurantAcknowledgesMissingOrderItems() onlyHandedToDeliveryPartnerWithMissingItemsOrder onlyRestaurant public {
        OrderItem[] memory orderItems = getMissingOrderItems();
        for (uint i = 0; i < orderItems.length; i++) {
            _orderValue -= orderItems[i].itemPrice;
        }
        _orderStatus = OrderStatus.HANDED_OVER_TO_DELIVERY_PARTNER;
    }

    /// @notice Only Customer can only accept order and only when the order state is in HANDED_OVER_TO_DELIVERY_PARTNER. When customre accepts the order
    ///     a. Order Value is transfered to the restaurant
    ///     b. Delivery Charge is transfered to Delivery partner
    ///     c. Platform Charges is transfered to Platform
    ///     d. Balance is transfered back to Customer
    ///   Order State is moved to DELIVERED_TO_CUSTOMER.
    function customerAcceptsOrder() onlyCustomer onlyHandedToDeliveryPartnerOrder public {

        _restaurantAddress.transfer(_orderValue);
        _deliveryPartnerAddress.transfer(_orderDeliveryCharge);
        _platformAddress.transfer(_platformCharge);
        _customerAddress.transfer(address(this).balance);

        _customerEscarowAmount = 0;
        _orderStatus = OrderStatus.DELIVERED_TO_CUSTOMER;
    }

    /// @dev utility function to find an element in array
    function find(uint[] storage array, uint value) private view returns(int) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return int(i);
            }
        }
        return -1;
    }

    /// @dev utility function to remove an element in array based on item value
    function removeByValue(uint[] storage array, uint value) private {
        int index = find(array, value);
        if(index > -1) {
            removeByIndex(array, uint(index));
        }
    }

    /// @dev utility function to remove an element in array based on item index
    function removeByIndex(uint[] storage array, uint index) private {
        array[index] = array[array.length - 1];
        array.pop();
    }
                                              
}

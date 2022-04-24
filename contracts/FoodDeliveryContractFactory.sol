// SPDX-License-Identifier: MIT

pragma solidity >=0.6.6 <0.9.0;

import "./FoodDeliveryContract.sol";

contract FoodDeliveryContractFactory { 

    uint orderCount;

    mapping(uint => FoodDeliveryContract) deliveryContracts;

    function createFoodDeliveryContract(address payable restaurantAddress, address payable deliveryPartnerAddress, address payable customerAddress, address payable platformAddress
                    , FoodDeliveryContract.OrderItem[] memory orderItems, uint orderDeliveryCharge, uint platformCharge) public returns (uint, FoodDeliveryContract) {
        FoodDeliveryContract foodDeliveryContract = new FoodDeliveryContract(restaurantAddress, deliveryPartnerAddress, customerAddress, platformAddress, orderItems
                    , orderDeliveryCharge, platformCharge);
        deliveryContracts[++orderCount] = foodDeliveryContract;
        return (orderCount, foodDeliveryContract);
    }

}

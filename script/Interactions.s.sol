//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCordinator, , , , ,uint256 deployerUint) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCordinator, deployerUint);
    }

    function createSubscription(
        address vrfCoordinatorV2,
        uint256 deployerUint
    ) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerUint);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinatorV2)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant Fund_Amount = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerUint
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCordinator, subId, link, deployerUint);
    }

    function fundSubscription(
        address vrfCordinator,
        uint64 subId,
        address link,
        uint256 deployerUint
    ) public {
        console.log("Funding Subscription: ", subId);
        console.log("Using VRFCordinator: ", vrfCordinator);
        console.log("OnChain id: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerUint);
            VRFCoordinatorV2Mock(vrfCordinator).fundSubscription(
                subId,
                Fund_Amount
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerUint);
            LinkToken(link).transferAndCall(
                vrfCordinator,
                Fund_Amount,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{

    function addConsumer(address vrfCordinator, uint64 subId, address raffle, uint256 deployerUint) public{
        console.log("Adding consumer contract: ", raffle);
        console.log("Using VRFCordinator: ", vrfCordinator);
        console.log("OnChain id: ", block.chainid);

        vm.startBroadcast(deployerUint);
        VRFCoordinatorV2Mock(vrfCordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public{
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerUint
        ) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCordinator, subId, raffle, deployerUint);
    }

    function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(contractAddress);
    }
}

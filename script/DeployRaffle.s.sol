//SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

pragma solidity ^0.8.17;

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entryfee,
            uint256 interval,
            address vrfCordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerUint
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // Creating a suscription
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCordinator,
                deployerUint
            );

            // Funding it!!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCordinator,
                subscriptionId,
                link,
                deployerUint
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entryfee,
            interval,
            vrfCordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(vrfCordinator, subscriptionId, address(raffle), deployerUint);

        return (raffle, helperConfig);
    }
}

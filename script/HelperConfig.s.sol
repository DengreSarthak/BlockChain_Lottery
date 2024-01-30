//SPDX-License-Identifier: MIT

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";

pragma solidity ^0.8.17;

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entryfee;
        uint256 interval;
        address vrfCordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerUint;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        uint256(
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvil();
        }
    }

    function getSepoliaNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            entryfee: 10,
            interval: 0,
            vrfCordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 8383,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerUint: vm.envUint("PRIVATE_KEY")
        });
        return sepoliaConfig;
    }

    function getOrCreateAnvil() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCordinator != address(0))
            return activeNetworkConfig;

        uint96 baseFee = 0.25 ether; // 0.25 link
        uint96 gasPriceLink = 1e9; // 1 gewe link

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mocks = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        vm.stopBroadcast();

        LinkToken link = new LinkToken();

        NetworkConfig memory anvilConvig = NetworkConfig({
            entryfee: 0.01 ether,
            interval: 30,
            vrfCordinator: address(vrfCoordinatorV2Mocks),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(link),
            deployerUint: DEFAULT_ANVIL_KEY
        });
        return anvilConvig;
    }
}

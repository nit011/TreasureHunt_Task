// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { TreasureHunt } from "../src/TreasureHunt.sol";

contract DeployTreasureHunt is Script {
    function run() external returns (TreasureHunt) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        uint256 initialReward = 0.1 ether; 
        vm.startBroadcast(deployerKey);
        TreasureHunt treasureHunt = new TreasureHunt();
        treasureHunt.initialize(initialReward);
        vm.stopBroadcast();
        return treasureHunt;
    }
}

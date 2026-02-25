// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std-1.14.0/Script.sol";
import {Escrow} from "../src/Escrow.sol";

contract Deploy is Script {
    function run() external {
        address usdc = vm.envAddress("USDC");
        address protocol = vm.envAddress("PROTOCOL");
        address forwarder = vm.envAddress("FORWARDER");

        vm.startBroadcast();
        Escrow escrow = new Escrow(usdc, protocol, forwarder);
        vm.stopBroadcast();

        console.log("Escrow deployed at:", address(escrow));
    }
}

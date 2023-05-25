// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdCheats.sol";
import { ECO } from "@helix-foundation/currency/contracts/currency/ECO.sol";
import { Policy } from "@helix-foundation/currency/contracts/policy/Policy.sol";
import { L1ECOBridge } from "../src/bridge/L1ECOBridge.sol";
import { L2ECOBridge } from "../src/bridge/L2ECOBridge.sol";
import { IL2ERC20Bridge, IL2ECOBridge } from "../src/interfaces/bridge/IL2ECOBridge.sol";
import { L1CrossDomainMessenger } from "@eth-optimism/contracts/L1/messaging/L1CrossDomainMessenger.sol";
import { L2CrossDomainMessenger } from "@eth-optimism/contracts/L2/messaging/L2CrossDomainMessenger.sol";
import { CrossDomainEnabledUpgradeable } from "../src/bridge/CrossDomainEnabledUpgradeable.sol";
import { L2ECO } from "../src/token/L2ECO.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { IECO } from "@helix-foundation/currency/contracts/currency/IECO.sol";


contract EcoTestSetup is Test {
    using stdStorage for StdStorage;

    uint256 L2_GAS_DISCOUNT_DIVISOR = 32;
    uint256 ENQUEUE_GAS_COST = 60_000;
    bytes NON_NULL_BYTES32 = "0x1111111111111111111111111111111111111111111111111111111111111111";

    uint256 mainnetFork;
    uint256 optimismFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    string OPTIMISM_RPC_URL = vm.envString("OPTIMISM_RPC_URL");

    address L1_ECO_ADDRESS = 0x8dBF9A4c99580fC7Fd4024ee08f3994420035727;
    address L1_PROXY_ADDRESS = 0xE70812Cecf8768f4dc6ff09eE1c3D121d5f23EB3;
    address L1_PAUSER_ADDRESS = 0x99f98ea4A883DB4692Fa317070F4ad2dC94b05CE;
    address L1_POLICY_ADDRESS = 0x8c02D4cc62F79AcEB652321a9f8988c0f6E71E68;
    address L1_OP_CROSS_DOMAIN_MESSENGER = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;
    address L1_OP_OLD_CROSS_DOMAIN_MESSENGER = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;
    address L2_OP_CROSS_DOMAIN_MESSENGER = 0x4200000000000000000000000000000000000007;

    uint256 INITIAL_INFLATION_MULTIPLIER = 1e18;
    uint256 INITIAL_TOTAL_L1_SUPPLY = 2e18;
    uint32 FINALIZATION_GAS = 1_200_000;

    address alice = 0x525cE685F31AF82C77Ab2C3d28F4be3a450b0c33;
    address bob = vm.addr(2);
    address impersonator = vm.addr(3);
    address pauser;

    ECO eco;
    Policy policy;
    L1ECOBridge l1EcoBridge;
    L1CrossDomainMessenger opL1CrossDomainMessenger;
    L2CrossDomainMessenger opL2CrossDomainMessenger;
    CrossDomainEnabledUpgradeable ecoCrossDomain;

    address l1XDomainMsgSender = address(0xdE1FCfB0851916CA5101820A69b13a4E276bd81F); 
    address l2XDomainMsgSender = address(0x000000000000000000000000000000000000dEaD);

    L2ECO l2Eco;
    L2ECOBridge l2EcoBridge;

    function setUp() public {
        setUpMainnet();
        setUpOptimism();
        intializeMainnet();
        intializeOptimism();
    }

    function setUpMainnet() internal {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);

        eco = ECO(L1_ECO_ADDRESS);
        policy = Policy(L1_POLICY_ADDRESS);
        pauser = L1_PAUSER_ADDRESS;
        opL1CrossDomainMessenger = L1CrossDomainMessenger(L1_OP_CROSS_DOMAIN_MESSENGER);

        vm.broadcast(alice);
        l1EcoBridge = new L1ECOBridge();
    }

    function setUpOptimism() internal {
        optimismFork = vm.createSelectFork(OPTIMISM_RPC_URL);
        opL2CrossDomainMessenger = L2CrossDomainMessenger(L2_OP_CROSS_DOMAIN_MESSENGER);

        vm.startBroadcast(alice);
        l2EcoBridge = new L2ECOBridge();
        l2Eco = new L2ECO();
        vm.stopBroadcast();
    }

    function intializeMainnet() internal {
        vm.selectFork(mainnetFork);
        
        vm.broadcast(alice);
        l1EcoBridge.initialize(
            L1_OP_CROSS_DOMAIN_MESSENGER,
            address(l2EcoBridge),
            address(eco),
            address(l2Eco),
            address(policy),
            alice
        );
    }

    function intializeOptimism() internal {
        vm.selectFork(optimismFork);

        vm.startBroadcast(alice);
        l2EcoBridge.initialize(
            L2_OP_CROSS_DOMAIN_MESSENGER,
            address(l1EcoBridge),
            address(eco),
            address(l2Eco),
            alice
        );
        l2Eco.initialize(
            address(eco),
            address(l2EcoBridge)
        );

        vm.stopBroadcast();
    }

    function testECOTransferMainnet() external {
        vm.selectFork(mainnetFork);

        uint256 aliceBalBef = eco.balanceOf(alice);
        uint256 bobBalBef = eco.balanceOf(bob);

        eco.transfer(bob, 10e18);

        uint256 aliceBalAft = eco.balanceOf(alice);
        uint256 bobBalAft = eco.balanceOf(bob);

        assertEq(aliceBalBef - 10e18, aliceBalAft);
        assertEq(bobBalBef + 10e18, bobBalAft);
    }

    function testForkSetup() external {
        vm.selectFork(optimismFork);
        assertTrue(true);

        vm.selectFork(mainnetFork);
        assertTrue(true);
    }
}
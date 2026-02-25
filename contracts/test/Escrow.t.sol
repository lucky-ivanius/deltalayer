// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std-1.14.0/Test.sol";
import {Escrow} from "../src/Escrow.sol";
import {IReceiver} from "../src/interfaces/IReceiver.sol";
import {IERC165} from "@openzeppelin-contracts-5.3.0/utils/introspection/IERC165.sol";
import {ERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EscrowTest is Test {
    Escrow public escrow;
    MockUSDC public usdc;

    address owner = address(this);
    address protocol = makeAddr("protocol");
    address forwarder = makeAddr("forwarder");
    address payer = makeAddr("payer");

    function setUp() public {
        usdc = new MockUSDC();
        escrow = new Escrow(address(usdc), protocol, forwarder);
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    function test_constructor() public view {
        assertEq(address(escrow.USDC()), address(usdc));
        assertEq(escrow.PROTOCOL(), protocol);
        assertEq(escrow.forwarder(), forwarder);
        assertEq(escrow.owner(), owner);
    }

    function test_constructor_revert_zero_usdc() public {
        vm.expectRevert(Escrow.ZeroAddress.selector);
        new Escrow(address(0), protocol, forwarder);
    }

    function test_constructor_revert_zero_protocol() public {
        vm.expectRevert(Escrow.ZeroAddress.selector);
        new Escrow(address(usdc), address(0), forwarder);
    }

    function test_constructor_revert_zero_forwarder() public {
        vm.expectRevert(Escrow.InvalidForwarder.selector);
        new Escrow(address(usdc), protocol, address(0));
    }

    // ──────────────────────────────────────────────
    // Settlement
    // ──────────────────────────────────────────────

    function _settle(
        bytes32 generation,
        bytes32 payment,
        uint256 paid,
        uint256 actual
    ) internal {
        bytes memory report = abi.encode(generation, payment, paid, actual, payer);
        vm.prank(forwarder);
        escrow.onReport("", report);
    }

    function _hash(bytes32 generation, bytes32 payment, uint256 paid, uint256 actual) internal pure returns (bytes32 h) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr,        generation)
            mstore(add(ptr, 32), payment)
            mstore(add(ptr, 64), paid)
            mstore(add(ptr, 96), actual)
            h := keccak256(ptr, 128)
        }
    }

    function test_settlement_full_refund() public {
        uint256 paid = 100e6;
        usdc.mint(address(escrow), paid);

        bytes32 payment = keccak256("tx1");
        _settle("gen_01", payment, paid, 0);

        assertEq(usdc.balanceOf(protocol), 0);
        assertEq(usdc.balanceOf(payer), paid);
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function test_settlement_partial_refund() public {
        uint256 paid = 100e6;
        uint256 actual = 60e6;
        usdc.mint(address(escrow), paid);

        bytes32 payment = keccak256("tx2");
        _settle("gen_01", payment, paid, actual);

        assertEq(usdc.balanceOf(protocol), actual);
        assertEq(usdc.balanceOf(payer), paid - actual);
        assertEq(usdc.balanceOf(address(escrow)), 0);
    }

    function test_settlement_no_refund() public {
        uint256 paid = 100e6;
        usdc.mint(address(escrow), paid);

        bytes32 payment = keccak256("tx3");
        _settle("gen_01", payment, paid, paid);

        assertEq(usdc.balanceOf(protocol), paid);
        assertEq(usdc.balanceOf(payer), 0);
    }

    function test_settlement_emits_event() public {
        uint256 paid = 100e6;
        uint256 actual = 40e6;
        usdc.mint(address(escrow), paid);

        bytes32 generation = "gen_01";
        bytes32 payment = keccak256("tx4");
        bytes32 hash = _hash(generation, payment, paid, actual);

        vm.expectEmit(true, true, true, true);
        emit Escrow.Settled(hash, generation, payment, paid, actual, paid - actual);

        _settle(generation, payment, paid, actual);
    }

    function test_settlement_stores_hash() public {
        uint256 paid = 100e6;
        usdc.mint(address(escrow), paid);

        bytes32 generation = "gen_01";
        bytes32 payment = keccak256("tx5");
        _settle(generation, payment, paid, 50e6);

        assertTrue(escrow.settled(_hash(generation, payment, paid, 50e6)));
    }

    // ──────────────────────────────────────────────
    // Replay protection
    // ──────────────────────────────────────────────

    function test_settlement_revert_replay() public {
        uint256 paid = 100e6;
        usdc.mint(address(escrow), paid * 2);

        bytes32 generation = "gen_01";
        bytes32 payment = keccak256("tx6");
        _settle(generation, payment, paid, 50e6);

        bytes32 hash = _hash(generation, payment, paid, 50e6);
        vm.expectRevert(abi.encodeWithSelector(Escrow.AlreadySettled.selector, hash));
        _settle(generation, payment, paid, 50e6);
    }

    // ──────────────────────────────────────────────
    // Access control
    // ──────────────────────────────────────────────

    function test_settlement_revert_unauthorized() public {
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes memory report = abi.encode(bytes32("gen"), bytes32(0), uint256(100), uint256(50), payer);
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.InvalidSender.selector, makeAddr("attacker"), forwarder)
        );
        escrow.onReport("", report);
    }

    // ──────────────────────────────────────────────
    // Validation
    // ──────────────────────────────────────────────

    function test_settlement_revert_actual_exceeds_paid() public {
        usdc.mint(address(escrow), 200e6);
        // forge-lint: disable-next-line(unsafe-typecast)
        bytes memory report = abi.encode(bytes32("gen"), bytes32(0), uint256(100e6), uint256(200e6), payer);
        vm.prank(forwarder);
        vm.expectRevert(
            abi.encodeWithSelector(Escrow.ActualExceedsPaid.selector, 200e6, 100e6)
        );
        escrow.onReport("", report);
    }

    // ──────────────────────────────────────────────
    // ERC165
    // ──────────────────────────────────────────────

    function test_supports_ireceiver() public view {
        assertTrue(escrow.supportsInterface(type(IReceiver).interfaceId));
    }

    function test_supports_ierc165() public view {
        assertTrue(escrow.supportsInterface(type(IERC165).interfaceId));
    }

    function test_does_not_support_random() public view {
        assertFalse(escrow.supportsInterface(0xdeadbeef));
    }

    // ──────────────────────────────────────────────
    // Admin
    // ──────────────────────────────────────────────

    function test_set_forwarder() public {
        address next = makeAddr("newForwarder");
        escrow.setForwarder(next);
        assertEq(escrow.forwarder(), next);
    }

    function test_set_forwarder_revert_zero() public {
        vm.expectRevert(Escrow.InvalidForwarder.selector);
        escrow.setForwarder(address(0));
    }

    function test_set_forwarder_revert_not_owner() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert();
        escrow.setForwarder(makeAddr("newForwarder"));
    }

    function test_set_forwarder_emits_event() public {
        address next = makeAddr("newForwarder");
        vm.expectEmit(true, true, false, false);
        emit Escrow.ForwarderUpdated(forwarder, next);
        escrow.setForwarder(next);
    }
}

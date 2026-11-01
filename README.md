# Adaptive AXI Interconnect with Starvation-Aware Arbitration and Verification

## Project Overview

This project presents a simplified AXI-style interconnect prototype designed to demonstrate efficient bus arbitration, starvation detection, address decoding, and memory access management.

The design supports two bus masters and two memory slaves. It implements fixed-priority and round-robin arbitration along with a starvation-aware mechanism to prevent a requesting master from waiting indefinitely.

The complete design is developed using Verilog HDL and verified using SystemVerilog testbenches in AMD Vivado 2025.1.

## Objectives

- Design a two-master, two-slave interconnect architecture.
- Implement fixed-priority and round-robin arbitration.
- Detect master starvation using programmable waiting thresholds.
- Provide starvation-aware arbitration priority.
- Implement address decoding for multiple memory slaves.
- Verify read and write transactions.
- Validate functionality through directed and randomized test scenarios.

## Architecture

**Main design blocks:**

1. Adaptive Arbiter
2. Starvation Monitor
3. Address Decoder
4. Memory Slave 0
5. Memory Slave 1
6. Interconnect Top Module

## Design Features

### Arbitration
- Fixed-priority arbitration.
- Round-robin arbitration.
- Active grant retention until transaction completion.
- Starvation-aware priority selection.

### Starvation Detection
- Individual waiting-cycle counters for both masters.
- Programmable starvation threshold.
- Starvation flag generation.
- Priority handling for starved masters.

### Address Decoding

| Address Range | Selected Slave |
|---|---|
| 0x00000000–0x00000FFF | Slave 0 |
| 0x00001000–0x00001FFF | Slave 1 |
| Other addresses | Invalid |

### Memory Interface
- Two synchronous memory slave models.
- Read and write operations.
- Readback verification.

## Verification Methodology

SystemVerilog testbenches are used to verify the design through directed and randomized testing.

### Test Scenarios

1. Master 0 memory write.
2. Master 0 readback.
3. Master 1 memory write.
4. Master 1 readback.
5. Round-robin arbitration.
6. Master 1 starvation detection and priority.
7. Master 0 starvation detection and priority.
8. Invalid address rejection.
9. Simultaneous master requests.
10. Sequential transactions.
11. Reset during active transaction and recovery.
12. Randomized write and readback operations.

## Simulation Results

- Total functional test scenarios: 12
- Test scenarios passed: 12
- Randomized verification: Passed
- Memory read/write: Passed
- Starvation detection: Passed
- Round-robin arbitration: Passed
- Invalid address handling: Passed
- Reset recovery: Passed
- Reported functional coverage: 88.89%

## Tools and Technologies

- Verilog HDL
- SystemVerilog
- AMD Vivado 2025.1
- XSim Simulator

## Current Project Status

RTL development and simulation-based functional verification have been completed successfully.

**Note:** Synthesis has not been completed because of a Vivado device-license issue. The current implementation is a simplified AXI-style prototype and is not a fully AXI-protocol-compliant interconnect.

## Future Enhancements

- Implement complete AXI VALID/READY handshaking.
- Support independent AXI AW, W, B, AR, and R channels.
- Extend the architecture to multiple masters and slaves.
- Perform synthesis and FPGA implementation.
- Improve verification coverage and protocol assertions.

## Author

**Reshma S.**

B.E. Electronics and Communication Engineering

Interested in RTL Design, VLSI, and Design Verification.

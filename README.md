# Kache-Risc-V
### Risc-V SOC written in verilog

Custom Pipelined 32-Bit Risc-V SOC to run on an FPGA<br>
End goal is to run Linux or a custom OS

#### Current Features
- Full RV32I ISA
- Extensions:
    - (M) Integer Multiply/Divide
    - (A) Atomic memory operations
    - (F) Single-Precision floating point support
    - (D) Double-Precision floating point support
    - (C) Compressed instruction support
    - (Zicsr) Control and Status Register support
- Full Supervisor/User Level ISA
    - Sv32 Virtual-Memory System
- 16Kb L1 Instruction Cache
    - 4-way Set Associative
    - Read Only
    - Virtually Indexed Physically Tagged
- 16Kb L1 Data Cache
    - 4-way Set Associative
    - Write back / Write allocate
    - Physically Indexed Physically Tagged
- Uses FPGA Block Memory programed during synthesys for BIOS and Bootloader
- SPI Flash stores Kernel and user programs
- UART for I/O

#### Planed Features
- Add support for DDR3 memory on the Arty-A7
- External storage (Micro SD) for loading programs

#### Other Potential Feautres
- Multicore Support
- V extension for Vector Operations
- Out-of-order processing
- Superscalar (Dual-issue) processing

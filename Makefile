######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################
RVARCH  = rv32imafdc
RVABI = ilp32d
RVTOOL_PREFIX := riscv64-unknown-elf
RVTOOL_DIR := /opt/riscv
RV_LIB_DIR := $(RVTOOL_DIR)/$(RVTOOL_PREFIX)/lib/$(RVARCH)/$(RVABI)
GCC_LIB_DIR := /opt/riscv/lib/gcc/riscv64-unknown-elf/10.1.0/$(RVARCH)/$(RVABI)

CC := $(RVTOOL_PREFIX)-gcc
LD := $(RVTOOL_PREFIX)-ld
OBJCOPY := $(RVTOOL_PREFIX)-objcopy
OBJDUMP := $(RVTOOL_PREFIX)-objdump
CFLAGS  := -O2 -march=$(RVARCH) -mabi=$(RVABI) -Wno-builtin-declaration-mismatch
CFLAGS  += -fno-pic -fno-stack-protector -w -nostdlib
LDFLAGS := -m elf32lriscv -nostdlib
LDFLAGS += -L$(RV_LIB_DIR) -lm $(GCC_LIB_DIR)/libgcc.a
ODFLAGS := -sj .data -dj .text

# Verilog
VSRC := $(shell find src/ -type f -name '*.v')
TOP  := SOC
XDC  := src/Extern/NexusA7.xdc

# Simulation
TB := verilator
TBFLAGS := -DBENCH -Wno-fatal --pins-inout-enables
TBFLAGS += --top-module $(TOP) --trace -cc -exe #--build
TBSRC := $(wildcard tb/*.cpp)

BIN_DIR := bin
BUILD_DIR := build

# Firmware
# SRC := $(wildcard firmware/OS/*.c)     $(wildcard firmware/OS/*.S)
# SRC += $(wildcard firmware/OS/*/*.c)   $(wildcard firmware/OS/*/*.S) 
# SRC += $(wildcard firmware/OS/*/*/*.c) $(wildcard firmware/OS/*/*/*.S) 
# OBJ := $(SRC:%=$(BUILD_DIR)/%.o)
# LDSCRIPT = firmware/OS/kernel.ld
SRC := firmware/Tests/startPipeline.S firmware/Tests/raystones.c
SRC += $(wildcard firmware/Tests/libs/*.S) $(wildcard firmware/Tests/libs/*.c) 
OBJ := $(SRC:%=$(BUILD_DIR)/%.o)
LDSCRIPT = firmware/Tests/ram.ld

# BIOS
SRCBIOS := firmware/Tests/startPipeline.S firmware/Tests/raystones.c
SRCBIOS += $(wildcard firmware/Tests/libs/*.S) $(wildcard firmware/Tests/libs/*.c) 
OBJBIOS := $(SRCBIOS:%=$(BUILD_DIR)/%.o)
LDSCRIPTBIOS = firmware/Tests/bios.ld

FIRMWARE := $(BIN_DIR)/firmware.elf
BIOS     := $(BIN_DIR)/bios.elf
BIN      := $(BIN_DIR)/bios.bin
BRAM     := $(BIN_DIR)/BRAM.hex

.PHONY: hex sim lint build dirs clean 

hex:   CFLAGS += -DBENCH 
sim:   CFLAGS += -DBENCH

hex:    $(BRAM) $(FIRMWARE)

$(BRAM): $(BIN)
	# hexdump -ve '"%08x\n"' $< > $@
	# hexdump -ve '1/8 "%016x\n"' $< > $@
	hexdump -ve '32/1 "%02x" "\n"' $< | \
		awk '{for(i=length($$0);i>0;i-=2)printf "%s",substr($$0,i-1,2);print""}' > $@

$(BIN): $(BIOS)
	$(OBJCOPY) $< -O binary $@

$(BIOS): $(OBJBIOS) $(LDSCRIPT) Makefile
	@mkdir -p $(dir $@)
	$(LD) -T $(LDSCRIPTBIOS) $(OBJBIOS) -o $@ $(LDFLAGS)
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DIR)/objdumpBIOS.txt

$(FIRMWARE): $(OBJ) $(LDSCRIPT) Makefile
	@mkdir -p $(dir $@)
	$(LD) -T $(LDSCRIPT) $(OBJ) -o $@ $(LDFLAGS)
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DIR)/objdumpFW.txt

$(BUILD_DIR)/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

sim: $(BRAM) $(FIRMWARE)
	rm -rf ./obj_dir
	$(TB) $(TBFLAGS) $(TBSRC) $(VSRC)
	cd obj_dir; make -f V$(TOP).mk
	cd obj_dir; ./V$(TOP) | tee ../$(BIN_DIR)/sim.log

$(BIN_DIR):
	mkdir -p $@

lint: clean $(BRAM)
	cd tcl; vivado -mode batch -nolog -nojournal \
		-source lint.tcl -tclargs $(VSRC) | tee lint.log

build: clean $(BRAM)
	cd tcl; vivado -mode batch -nolog -nojournal \
		-source build.tcl -tclargs $(VSRC) | tee build.log

upload:
	cd tcl; vivado -mode tcl -nolog -nojournal -source upload.tcl | tee upload.log

store:
	cd tcl; vivado -mode tcl -nolog -nojournal -source store.tcl | tee store.log

clean:
	rm -rf ./obj_dir
	rm -rf $(BIN_DIR)
	rm -rf $(BUILD_DIR)


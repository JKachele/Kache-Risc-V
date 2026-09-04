######################################################################
# @author      : Justin Kachele (justin@kachele.com)
# @file        : Makefile
# @created     : Friday Oct 17, 2025 14:39:28 UTC
######################################################################
RVTOOL_PREFIX := riscv64-unknown-elf
CC := $(RVTOOL_PREFIX)-gcc
LD := $(RVTOOL_PREFIX)-ld
OBJCOPY := $(RVTOOL_PREFIX)-objcopy
OBJDUMP := $(RVTOOL_PREFIX)-objdump

ARCH  := rv32imafdc
RVARCH := $(shell $(CC) --print-multi-lib | awk -F '[/;]' '/$(ARCH)_/ {print $$1}')
RVABI  := $(shell $(CC) --print-multi-lib | awk -F '[/;]' '/$(ARCH)_/ {print $$2}')
RVTOOL_DIR := /opt/riscv
RVTOOL_BIN_PREFIX := $(RVTOOL_DIR)/bin/$(RVTOOL_PREFIX)
RV_LIB_DIR := $(RVTOOL_DIR)/$(RVTOOL_PREFIX)/lib/$(RVARCH)/$(RVABI)
GCC_LIB_DIR := $(RVTOOL_DIR)/lib/gcc/$(RVTOOL_PREFIX)/16.1.0/$(RVARCH)/$(RVABI)

CFLAGS  := -g0 -O2 -march=$(RVARCH) -mabi=$(RVABI) -std=c99
CFLAGS  += -Wno-builtin-declaration-mismatch -fno-pic -fno-stack-protector -w -nostdlib
LDFLAGS := -O2 -S -m elf32lriscv -nostdlib
LDFLAGS += -L$(RV_LIB_DIR) -lm $(GCC_LIB_DIR)/libgcc.a
ODFLAGS := -sj .data -sj .rodata -sj .sdata -dj .text -dj .text.start -dj .text.bios

# Verilog
VSRC := $(shell find src/ -type f -name '*.v')
TOP  := SOC
XDC  := src/Extern/NexusA7.xdc

# Simulation
TB := verilator
TBFLAGS := -DBENCH -Wno-fatal --pins-inout-enables
TBFLAGS += --top-module $(TOP) --trace-vcd -cc -exe #--build
TBSRC := $(wildcard tb/*.cpp) $(wildcard tb/*/*.cpp)

BIN_DIR := bin
BIN_DUMP_DIR := bin/dump
BUILD_DIR := build

# Application
SRCAPP := $(wildcard firmware/OS/apps/Shell/*.c)
SRCAPP += $(wildcard firmware/OS/apps/*.c) $(wildcard firmware/OS/apps/*.S)
SRCAPP += $(shell find firmware/OS/kernel/libs/ -type f -name '*.c' -o -name '*.S')
OBJAPP := $(SRCAPP:%=$(BUILD_DIR)/%.o)
LDSCRIPTAPP = firmware/OS/apps/user.ld

# Kernel
SRCKERNEL := $(shell find firmware/OS/kernel/ -type f -name '*.c' -o -name '*.S')
OBJKERNEL := $(SRCKERNEL:%=$(BUILD_DIR)/%.o)
LDSCRIPTKERNEL = firmware/OS/kernel/kernel.ld

# BIOS and Bootloader
SRCBIOS := $(shell find firmware/OS/BIOS/ -type f -name '*.c' -o -name '*.S')
OBJBIOS := $(SRCBIOS:%=$(BUILD_DIR)/%.o)
LDSCRIPTBIOS = firmware/OS/BIOS/bios.ld

APP      := $(BIN_DIR)/app.elf
APPBIN   := $(BIN_DIR)/app.bin
KERNEL   := $(BIN_DIR)/kernel.elf
BIOS     := $(BIN_DIR)/bios.elf
BIN      := $(BIN_DIR)/bios.bin
BRAM     := $(BIN_DIR)/BRAM.hex

.PHONY: hex sim lint build dirs clean 

hex sim simt:   CFLAGS += -DBENCH

hex:    $(BRAM) $(KERNEL) $(APP)

$(BRAM): $(BIN)
	# hexdump -ve '"%08x\n"' $< > $@
	# hexdump -ve '1/8 "%016x\n"' $< > $@
	hexdump -ve '32/1 "%02x" "\n"' $< | \
		awk '{for(i=length($$0);i>0;i-=2)printf "%s",substr($$0,i-1,2);print""}' > $@

$(BIN): $(BIOS)
	$(OBJCOPY) $< -O binary $@

$(BIOS): $(OBJBIOS) $(LDSCRIPTBIOS) Makefile
	@mkdir -p $(dir $@)
	@mkdir -p $(BIN_DUMP_DIR)
	$(LD) -T $(LDSCRIPTBIOS) $(OBJBIOS) -o $@ $(LDFLAGS)
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DUMP_DIR)/objdumpBIOS.txt
	readelf -a $@ > $(BIN_DUMP_DIR)/readelfBIOS.txt

$(KERNEL): $(OBJKERNEL) $(LDSCRIPTKERNEL) $(APP) Makefile
	@mkdir -p $(dir $@)
	@mkdir -p $(BIN_DUMP_DIR)
	$(LD) -T $(LDSCRIPTKERNEL) $(OBJKERNEL) $(APPBIN).o -o $@ $(LDFLAGS)
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DUMP_DIR)/objdumpKernel.txt
	readelf -a $@ > $(BIN_DUMP_DIR)/readelfKernel.txt
	$(OBJCOPY) $@ -O binary $(BIN_DIR)/kernel.bin

$(APP): $(OBJAPP) $(LDSCRIPTAPP) Makefile
	@mkdir -p $(dir $@)
	@mkdir -p $(BIN_DUMP_DIR)
	$(LD) -T $(LDSCRIPTAPP) $(OBJAPP) -o $@ $(LDFLAGS)
	$(OBJCOPY) --set-section-flags .bss=alloc,contents -O binary $@ $(BIN_DIR)/app.bin
	$(OBJCOPY) -Ibinary -Oelf32-littleriscv $(BIN_DIR)/app.bin $(BIN_DIR)/app.bin.o
	$(OBJDUMP) $(ODFLAGS) $@ > $(BIN_DUMP_DIR)/objdumpApp.txt
	readelf -a $@ > $(BIN_DUMP_DIR)/readelfApp.txt

$(BUILD_DIR)/%.S.o: %.S
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) -o $@ -c $< $(CFLAGS)

sim: $(BRAM) $(KERNEL)
	rm -rf ./obj_dir
	$(TB) $(TBFLAGS) $(TBSRC) $(VSRC)
	cd obj_dir; make -f V$(TOP).mk
	cd obj_dir; ./V$(TOP) | tee ../$(BIN_DIR)/sim.log &
	@sleep 1 # Wait for TCP Socket to be ready
	@socat -,rawer TCP4:localhost:54000,connect-timeout=5

simt: $(BRAM) $(KERNEL)
	rm -rf ./obj_dir
	$(TB) $(TBFLAGS) -CFLAGS -DTRACE $(TBSRC) $(VSRC)
	cd obj_dir; make -f V$(TOP).mk
	cd obj_dir; ./V$(TOP) | tee ../$(BIN_DIR)/sim.log &
	@sleep 1
	@socat -,rawer TCP4:localhost:54000,connect-timeout=5
	vcd2fst obj_dir/trace.vcd obj_dir/trace.fst

$(BIN_DIR):
	mkdir -p $@

lint: clean $(BRAM)
	cd tcl; vivado -mode batch -nolog -nojournal \
		-source lint.tcl -tclargs $(VSRC) | tee lint.log

build: clean $(BRAM) $(KERNEL)
	cd tcl; vivado -mode batch -nolog -nojournal \
		-source build.tcl -tclargs $(VSRC) | tee build.log

upload:
	cd tcl; vivado -mode tcl -nolog -nojournal -source upload.tcl | tee upload.log

store: $(BRAM) $(KERNEL)
	cd tcl; vivado -mode tcl -nolog -nojournal -source store.tcl | tee store.log

clean:
	rm -rf obj_dir
	rm -rf $(BIN_DIR)
	rm -rf $(BUILD_DIR)


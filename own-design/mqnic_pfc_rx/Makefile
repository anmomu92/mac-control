# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

# verilog source files
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../rtl/pfc_rx_fifo.v

DUT      = mqnic_pfc_rx
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)

# module parameters
export PARAM_DATA_WIDTH ?= 64
export PARAM_KEEP_ENABLE ?= $(shell expr $(PARAM_DATA_WIDTH) \> 8 )
export PARAM_KEEP_WIDTH ?= $(shell expr \( $(PARAM_DATA_WIDTH) + 7 \) / 8 )
export PARAM_LAST_ENABLE ?= 1
export PARAM_ID_ENABLE ?= 1
export PARAM_ID_WIDTH ?= 8
export PARAM_DEST_ENABLE ?= 1
export PARAM_DEST_WIDTH ?= 8
export PARAM_USER_ENABLE ?= 1
export PARAM_USER_WIDTH ?= 1


ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).KEEP_ENABLE=$(PARAM_KEEP_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).KEEP_WIDTH=$(PARAM_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).LAST_ENABLE=$(PARAM_LAST_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).ID_ENABLE=$(PARAM_ID_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).ID_WIDTH=$(PARAM_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).DEST_ENABLE=$(PARAM_DEST_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).DEST_WIDTH=$(PARAM_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).USER_ENABLE=$(PARAM_USER_ENABLE)
	COMPILE_ARGS += -P $(TOPLEVEL).USER_WIDTH=$(PARAM_USER_WIDTH)
	
	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GKEEP_ENABLE=$(PARAM_KEEP_ENABLE)
	COMPILE_ARGS += -GKEEP_WIDTH=$(PARAM_KEEP_WIDTH)
	COMPILE_ARGS += -GLAST_ENABLE=$(PARAM_LAST_ENABLE)
	COMPILE_ARGS += -GID_ENABLE=$(PARAM_ID_ENABLE)
	COMPILE_ARGS += -GID_WIDTH=$(PARAM_ID_WIDTH)
	COMPILE_ARGS += -GDEST_ENABLE=$(PARAM_DEST_ENABLE)
	COMPILE_ARGS += -GDEST_WIDTH=$(PARAM_DEST_WIDTH)
	COMPILE_ARGS += -GUSER_ENABLE=$(PARAM_USER_ENABLE)
	COMPILE_ARGS += -GUSER_WIDTH=$(PARAM_USER_WIDTH)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst

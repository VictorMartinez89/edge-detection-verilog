# Edge-detection hardware: lint, self-checking testbench and cocotb regression.
#   make lint   compile every RTL file with Icarus (catches undeclared nets that Yosys accepts silently)
#   make tb     run the SystemVerilog testbench of the combinational cores
#   make test   run the cocotb tests against the Python golden models
#   make all    the three of them (what CI runs)

RTL   := $(wildcard rtl/*.sv)
BUILD := build
IVERILOG ?= iverilog -g2012 -Wall -Wno-timescale

# cocotb tests: name -> toplevel and sources
COCOTB_TESTS := sobel_compass canny nms
TOP_sobel_compass := sobel_compass_control
SRC_sobel_compass := rtl/sobel_compass_control.sv rtl/sobel_compass_core.sv
TOP_canny := canny_control
SRC_canny := rtl/canny_control.sv rtl/canny_full_core.sv
TOP_nms   := nms_core
SRC_nms   := rtl/nms_core.sv

.PHONY: all lint tb test $(addprefix test-,$(COCOTB_TESTS)) clean

all: lint tb test

lint: | $(BUILD)
	$(IVERILOG) -o $(BUILD)/lint.vvp $(RTL)
	@echo "lint OK: $(words $(RTL)) files"

tb: | $(BUILD)
	$(IVERILOG) -o $(BUILD)/tb_filters.vvp tb/tb_filters.sv \
	    rtl/sobel_compass_core.sv rtl/gaussian_core.sv rtl/isqrt.sv rtl/canny_grad_threshold_core.sv
	vvp -n $(BUILD)/tb_filters.vvp | tee $(BUILD)/tb_filters.log
	@grep -q "ALL TESTS PASSED" $(BUILD)/tb_filters.log

test: $(addprefix test-,$(COCOTB_TESTS))

# One explicit rule per test (make skips pattern rules for .PHONY targets).
# COMPILE_ARGS goes in the environment: on the command line it would override cocotb's own += (timescale).
# -r: no built-in rules (otherwise make tries to "rebuild" makefiles from same-named sources)
define COCOTB_RULE
test-$(1): | $(BUILD)
	rm -f $(BUILD)/results_$(1).xml
	COMPILE_ARGS=-g2012 $(MAKE) -r -f $$(shell cocotb-config --makefiles)/Makefile.sim \
	    SIM=icarus TOPLEVEL_LANG=verilog \
	    TOPLEVEL=$(TOP_$(1)) COCOTB_TEST_MODULES=test_$(1) \
	    VERILOG_SOURCES="$(addprefix $(CURDIR)/,$(SRC_$(1)))" \
	    SIM_BUILD=$(CURDIR)/$(BUILD)/sim_$(1) COCOTB_RESULTS_FILE=$(CURDIR)/$(BUILD)/results_$(1).xml \
	    PYTHONPATH=$(CURDIR)/tests
	@test -f $(BUILD)/results_$(1).xml && ! grep -q "<failure" $(BUILD)/results_$(1).xml
endef
$(foreach t,$(COCOTB_TESTS),$(eval $(call COCOTB_RULE,$(t))))

$(BUILD):
	mkdir -p $@

clean:
	rm -rf $(BUILD) __pycache__ tests/__pycache__

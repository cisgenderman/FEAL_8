IVERILOG ?= iverilog
VVP ?= vvp

# IMPORTANT: The package MUST be compiled before modules importing it.
RTL = ../rtl/feal_s_pkg.sv ../rtl/feal_f.sv ../rtl/feal_fk.sv \
      ../rtl/feal_round.sv ../rtl/key_schedule.sv \
      ../rtl/feal_core.sv ../rtl/feal_axi.sv
BUILD = ../build

.PHONY: all sim test-keys test-f clean
all: sim test-keys test-f

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/feal.vvp: $(RTL) tb_feal.sv | $(BUILD)
	$(IVERILOG) -g2012 -s tb_feal -I../rtl -o $@ $(RTL) tb_feal.sv

sim: $(BUILD)/feal.vvp
	$(VVP) $(BUILD)/feal.vvp

$(BUILD)/feal_key.vvp: $(RTL) tb_key_schedule.sv | $(BUILD)
	$(IVERILOG) -g2012 -s tb_key_schedule -I../rtl -o $@ $(RTL) tb_key_schedule.sv

test-keys: $(BUILD)/feal_key.vvp
	$(VVP) $(BUILD)/feal_key.vvp

$(BUILD)/feal_f.vvp: ../rtl/feal_s_pkg.sv ../rtl/feal_f.sv tb_feal_f.sv | $(BUILD)
	$(IVERILOG) -g2012 -s tb_feal_f -I../rtl -o $@ ../rtl/feal_s_pkg.sv ../rtl/feal_f.sv tb_feal_f.sv

test-f: $(BUILD)/feal_f.vvp
	$(VVP) $(BUILD)/feal_f.vvp

clean:
	rm -f $(BUILD)/feal.vvp $(BUILD)/feal_key.vvp $(BUILD)/feal_f.vvp feal_wave.vcd

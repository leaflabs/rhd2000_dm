## Copyright (c) 2015 LeafLabs LLC
## Author: Charlie Lamantia
## Date: December 2015

## Makefile for use with iverilog and gtkwave


# Verilog source files
VER := rhd2000_dm.v
VER += llLib.v

# Testbench
TB := rhd2000_dm_tb.v

# Testbench output as defined by "$dumpfile("test.vcd");"
# called in testbench "initial begin"
TBO = test.vcd

# Compiled output from iverilog
CO = c.o


# make targets
simulate: $(CO)
	vvp -v $(CO) -lxt

display: $(TBO)
	gtkwave $(TBO) &


# make dependancies
$(TBO): $(CO)
	vvp $(CO) -lxt

$(CO): $(TB) $(VER)
	iverilog -v -o $(CO) $(TB) $(VER)
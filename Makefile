###############################################################################
#
# ICARUS VERILOG & GTKWAVE MAKEFILE
# MADE BY WILLIAM GIBB FOR HACDC
# williamgibb@gmail.com
# 
# USE THE FOLLOWING COMMANDS WITH THIS MAKEFILE
#	"make check" - compiles your verilog design - good for checking code
#	"make simulate" - compiles your design+TB & simulates your design
#	"make display" - compiles, simulates and displays waveforms
# 
###############################################################################
#
# CHANGE THESE THREE LINES FOR YOUR DESIGN
#
#TOOL INPUT

SRC := rhd2000_dm.v
SRC += llLib.v

TESTBENCH = rhd2000_dm_tb.v

#THIS NEEDS TO MATCH THE OUTPUT FILE
#FROM YOUR TESTBENCH
TBOUTPUT = test.vcd
###############################################################################
# BE CAREFUL WHEN CHANGING ITEMS BELOW THIS LINE
###############################################################################
#TOOLS
COMPILER = iverilog
SIMULATOR = vvp
VIEWER = gtkwave
#TOOL OPTIONS
COFLAGS = -v -o
SFLAGS = -v

#SIMULATOR OUTPUT TYPE
SOUTPUT = -lxt

#TOOL OUTPUT
#COMPILER OUTPUT
COUTPUT = compiler.out
###############################################################################
#MAKE DIRECTIVES
check : $(TESTBENCH) $(SRC)
	$(COMPILER) -v $(SRC)

simulate: $(COUTPUT)
	$(SIMULATOR) $(SFLAGS) $(COUTPUT) $(SOUTPUT)

display: $(TBOUTPUT)
	$(VIEWER) $(TBOUTPUT) &
#MAKE DEPENDANCIES
$(TBOUTPUT): $(COUTPUT)
	$(SIMULATOR) $(SOPTIONS) $(COUTPUT) $(SOUTPUT)

$(COUTPUT): $(TESTBENCH) $(SRC)
	$(COMPILER) $(COFLAGS) $(COUTPUT) $(TESTBENCH) $(SRC)
vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xpm
vlib questa_lib/msim/xil_defaultlib

vmap xpm questa_lib/msim/xpm
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm  -93  \
"C:/Xilinx/2025.1/Vivado/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  -sv "+incdir+../../../../../Xilinx/2025.1/Vivado/data/rsb/busdef" \
"../../../obc_da_project.srcs/sources_1/new/ng.sv" \
"../../../obc_da_project.srcs/sim_1/new/tb_obc_da_integer_9input.sv" \

vlog -work xil_defaultlib \
"glbl.v"


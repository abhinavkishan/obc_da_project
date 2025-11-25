transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

asim +access +r +m+tb_obc_da_integer_9input  -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.tb_obc_da_integer_9input xil_defaultlib.glbl

do {tb_obc_da_integer_9input.udo}

run 1000ns

endsim

quit -force

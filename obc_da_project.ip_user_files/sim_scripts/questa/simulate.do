onbreak {quit -f}
onerror {quit -f}

vsim  -lib xil_defaultlib tb_obc_da_integer_9input_opt

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {tb_obc_da_integer_9input.udo}

run 1000ns

quit -force

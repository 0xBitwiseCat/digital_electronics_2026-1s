# top.sdc — Restricciones de Temporización
# Reloj principal: 50 MHz en PIN_23

create_clock -period 20.000 -name clk [get_ports clk]

derive_clock_uncertainty

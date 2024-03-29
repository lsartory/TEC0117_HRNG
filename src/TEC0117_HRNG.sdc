create_clock -name CLK_100MHz -period 10 [get_ports {CLK_100MHz}]
create_generated_clock -name pll_clk -source [get_ports {CLK_100MHz}] -master_clock CLK_100MHz -divide_by 5 -multiply_by 2 [get_nets {pll_clk}]

set_false_path -from [get_ports {USER_BTN}]

report_max_frequency -mod_ins {por_cs}
report_max_frequency -mod_ins {display_cs}
report_max_frequency -mod_ins {rng}
report_max_frequency -mod_ins {sha256}
report_max_frequency -mod_ins {uart}
report_max_frequency -mod_ins {pdm_gen[1].pdm}
report_max_frequency -mod_ins {pdm_gen[2].pdm}
report_max_frequency -mod_ins {pdm_gen[3].pdm}
report_max_frequency -mod_ins {pdm_gen[4].pdm}
report_max_frequency -mod_ins {pdm_gen[5].pdm}
report_max_frequency -mod_ins {pdm_gen[6].pdm}
report_max_frequency -mod_ins {pdm_gen[7].pdm}
report_max_frequency -mod_ins {pdm_gen[8].pdm}

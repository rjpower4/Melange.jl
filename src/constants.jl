# FILE  : src/constants.jl
# BRIEF : definition of constants with no other dependencies

b1900() = 2_415_020.313_52
b1950() = 2_433_282.423_459_05
j1900() = 2_415_020.0
j1950() = 2_433_282.5
j2000() = 2_451_545.0
j2100() = 2_488_070.0
julian_year() = 31_557_600.0
seconds_per_day() = 86_400.0

""" 
    $(FUNCTIONNAME)() 

Returns the IAU official value for the speed of light in a vacuum in km/sec.
"""
speed_of_light() = 299_792.458

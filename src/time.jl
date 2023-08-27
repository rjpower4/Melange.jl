# FILE  : src/time.jl
# BRIEF : definitions of useful time functions/values


"""
    $(FUNCTIONNAME)()

Convert Julian date to UTC seconds past J2000.
"""
seconds_past_j2000(jdate) = (jdate - j2000()) * seconds_per_day()

"""
    $(FUNCTIONNAME)()

Convert number of seconds past J2000 to Julian date.
"""
julian_date(seconds) = j2000() + seconds / seconds_per_day()


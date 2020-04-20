﻿-- DROP TYPE diffusion_wind.scoe_return_2;

CREATE TYPE diffusion_wind.scoe_return_2 AS
   (scoe double precision,
    nturb numeric,
    nem_available boolean);
ALTER TYPE diffusion_wind.scoe_return_2
  OWNER TO "diffusion-writers";


-- Function: diffusion_wind.scoe(numeric, numeric, numeric, double precision, numeric, numeric, numeric, numeric)

-- DROP FUNCTION diffusion_wind.scoe_2(numeric, numeric, numeric, double precision, numeric, numeric, numeric, numeric);
set role 'server-superusers';
CREATE OR REPLACE FUNCTION diffusion_wind.scoe_2(load_kwh_per_customer_in_bin numeric, naep numeric, turbine_size_kw numeric, nem_system_size_limit_kw double precision, sys_size_target_nem numeric, sys_oversize_limit_nem numeric, sys_size_target_no_nem numeric, sys_oversize_limit_no_nem numeric)
  RETURNS diffusion_wind.scoe_return_2 AS
$BODY$

    """ Calculate simple metric for evaluating optimal capacity-height among several
        possibilities. The metric does not caclulate value of incentives, which are 
        assumed to scale btw choices."""


    if nem_system_size_limit_kw == 0:
        # if not net metering, the target percentage of load is sys_size_target_no_nem
        # and the oversize limit is the sys_oversize_limit_no_nem
        target_kwh = load_kwh_per_customer_in_bin * sys_size_target_no_nem
        oversize_limit_kwh = load_kwh_per_customer_in_bin * sys_oversize_limit_no_nem
        # set nem availability to false
        nem_available = False
    elif nem_system_size_limit_kw > 0:
        # if there is net metering...
        # the target percentage of load is sys_size_target_nem
        target_kwh = load_kwh_per_customer_in_bin * sys_size_target_nem
        oversize_limit_kwh = load_kwh_per_customer_in_bin * sys_oversize_limit_nem
        nem_available = True

    # calculate the system generation from naep and turbine_size_kw
    aep = turbine_size_kw * naep

    # check whether the aep is equal to zero or whether the system is above the oversize limit
    if aep == 0 or aep > oversize_limit_kwh:
            # if so,  return very high cost
            scoe = float('inf')
            nturb = 0
            nem_available = False
            return scoe, nturb, nem_available     
    
    # if the turbine is the max turbine size (1.5 MW) and less than the target generation
    # determine whether multiple turbines should be installed
    if turbine_size_kw == 1500 and aep < target_kwh:
        # This indicates we want a project larger than 1500 kW. Return -1 scoe
        # and the optimal continuous number of turbines
        scoe = 0
        nturb  = target_kwh/aep
        nturb = min(4, nturb) #Don't allow projects larger than 6 MW
    else:
        # for remaining conditions, 
        # calculate the absolute difference of how far the aep is from the target generation
        scoe = abs(aep-target_kwh)            
        nturb = 1    
        
    # check that the system is within the net metering size limit
    if turbine_size_kw > nem_system_size_limit_kw:
        # if not, multiply the normal scoe by a factor of 2
        scoe = scoe * 2
        nem_available = False 

    return scoe, nturb, nem_available

  $BODY$
  LANGUAGE plpythonu STABLE
  COST 100;

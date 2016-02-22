#!/bin/bash
# Example usage: ./run_R_codes.sh fairness_mode[0/1/4] topology[2_2/2_3/3_2]

Rscript get_assignment.R 0 $1 conflict_$2.dat stats_$2.dat route_0.dat
cat route_0.dat

Rscript get_assignment.R 1 $1 conflict_$2.dat stats_$2.dat route_1.dat
cat route_1.dat

Rscript get_assignment.R 4 $1 conflict_$2.dat stats_$2.dat route_4.dat
cat route_4.dat

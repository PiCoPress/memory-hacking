#!/bin/bash

# This tool uses xxd, so you need to install it.
# Limitation: Can't write null byte due to bash restriction
# Well, do I need to port it to perl?..

MEMSIZE=$(lsmem --summary=never -n -o RANGE | tail -n1 | cut -d'-' -f2);
MEMSIZE=$(($MEMSIZE)); 

function injection() {
	local len=$1;	# payload size (byte)
	local perf=$2;	# perform count

	[[ -z $len ]] && len=1;
	[[ -z $perf ]] && perf=128;

	perl ./perform.pl $MEMSIZE $perf $len;
}

alias inj="injection";

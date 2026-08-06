#!/bin/bash

# This tool uses xxd, so you need to install it.
# Limitation: Can't write null byte due to bash restriction
# Well, do I need to port it to perl?..

MEMSIZE=$(lsmem --summary=never -n -o RANGE | tail -n1 | cut -d'-' -f2)
MEMSIZE=$(($MEMSIZE))

function rand() {
	# $1: max value (64bit positive integer expected)
	local num=$(dd if=/dev/random bs=8 count=1 status=none | od -An -t u8 | tr -d ' ' | head -c 18);
	echo $(($num%$1));
}

function injection() {
	local len=$1;	# payload size (byte)
	local perf=$2;	# perform count
	local dump=$3;	# modification dump base file name

	local v="";		# writing value
	local addr="";	# writing address

	[[ -z $len ]] && len=1;
	[[ -z $perf ]] && perf=128;

	if [[ -z $dump ]]; # no filename specified
	then
		for ((i = 0; i < $perf; i += 1));
		do
			dd status=none if=/dev/urandom of=/dev/mem bs=1 count=$len seek=$(rand $MEMSIZE);
		done
	else
		echo "================" >> $dump;
		printf 'len=%d\tperf=%d\n' $len $perf >> $dump;

		for ((i = 0; i < $perf; i += 1));
		do
			v=$(dd if=/dev/urandom bs=1 count=$len status=none);
			addr=$(rand $MEMSIZE);

			printf '%016x\t%s\n' $addr $(printf '%b' "$v" | xxd -ps -c0) >> $dump;

			printf '%b' "$v" | dd status=none of=/dev/mem bs=1 count=$len seek=$addr;
		done
		echo "change has been recorded at: $dump";
	fi
}

alias inj="injection"

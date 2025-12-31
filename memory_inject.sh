MEMSIZE=$(lsmem --summary=never -n -o RANGE | tail -n1 | cut -d'-' -f2)
MEMSIZE=$(($MEMSIZE))
function rand() { 
	local tmp=$(dd if=/dev/random bs=8 count=1 status=none | od -An -t u8 | tr -d ' ' | head -c 18); 
	echo $(($tmp%($MEMSIZE/$1))); 
}
function injection() { 
	local tmp=$1; 
	local tmp2=$2; 
	[[ -z $tmp ]] && tmp=1; 
	[[ -z $tmp2 ]] && tmp2=128; 
	cat /dev/urandom | dd status=none of=/dev/mem count=$tmp bs=$tmp2 seek=$(rand $tmp2); 
}
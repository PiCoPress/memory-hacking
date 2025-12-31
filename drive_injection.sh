function drive_rand() { 
        local inodes=$(df --output=itotal -B 1 / | tail -n1)
        local tmp=$(dd if=/dev/random bs=8 count=1 status=none | od -An -t u8 | tr -d ' ' | head -c 18); 
        echo $(($tmp%$inodes)); 
}
function drive_injection() { 
	local retry=1000;
        local tmp=$1; # Offset
        local tmp2=$2; # Length
        local rand_v=$(drive_rand);
        local count=0;
        local root=$(df --output=source / | tail -n1);
        local out="";
        [[ -z $tmp ]] && tmp=0; 
        [[ -z $tmp2 ]] && tmp2=1; 
        while [[ true ]];
        do;
                if [[ $count -gt retry ]];
                then;
                        echo "failed to find a valid inode (tried $retry times)";
                        return 2;
                fi;
                out=$(debugfs -nR "ncheck $rand_v" $root 2>> /dev/null | tail -n+2 | tail -n1 | cut -f2);
                [[ $out ]] && break;
                rand_v=$(drive_rand);
                count=$(($count+1));
        done;
        echo "Injecting to:" $out;
        out=$(echo $(debugfs -nR "blocks \"$out\"" $root 2>> /dev/null | tail -n1 | cut -d ' ' -f1));
	if [[ -z $out ]]; 
	then;
		echo "Unfortunately, this file has no physical blocks (maybe size 0)."
		return 1;
	fi;
        out=$(($out*4*1024+$tmp));
        cat /dev/urandom | dd status=none of=$root count=$tmp2 bs=1 seek=$out;
}

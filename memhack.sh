#!/bin/bash

# [$n] = optional
#
# $1: action
#       put = p
#               $2: offset
#               [$3]: new byte, write bytes by $3 length.
#                       if empty, next target is stdin.
#       get = g
#               $2: offset
#               [$3]: byte length, default is 256

mem="/dev/mem"

function getlen()
{
        local len=$(echo -e "$1" | wc -c)
        len=$(expr $len - 1)
        echo $len
}

function writeat()
{
        # $1: output
        # $2: offset
        # $3: count
        #
        # default input: stdin

        dd of=$1 status=none bs=1 seek=$(($2)) count=$3 conv=notrunc
}

function lsvaddr()
{
        local table=$(pmap $1 | tail -n +2 | head -n -1 | cut -d' ' -f1)
        echo "$table"
}

case $1 in
        put | p )
                data=${@:3}
                len=$(getlen "$data")
                if [[ -z $2 ]];
                then
                        echo "nothing to do"
                        exit 1
                elif [[ $len -eq 0 ]];
                then
                        echo -e "reading from stdin.."
                        data=$(cat /dev/stdin)
                        len=$(getlen "$data")
                fi
                echo -e "$data" | writeat $mem $2 $len
                echo -e "Memory value altered."
        ;;
        set | s )
                # $2    offset
                # $3    size
                # $4    a byte(0~255)

                byte=$4
                size=$(($3))
                offset=$(($2))
                if [[ -z $2 ]] || [[ -z $3 ]];
                then
                        echo -e "both offset and size are need"
                        exit 2
                fi
                if [[ -z $byte ]];
                then
                        byte=0
                elif [[ $byte -gt 255 ]] || [[ $byte -lt 0 ]];
                then
                        echo -e "cond: 0 <= size < 256"
                        exit 3
                fi
                char=$(printf "%x" $byte)
                perl -E 'say "\x'$char'"x'$size | writeat $mem $offset $size
                echo -e "value has been altered."
        ;;
        get | g )
                arg3=$3
                chop="less"
                if [[ -z $arg3 ]];
                then
                        arg3=256
                fi
                if [[ $arg3 -lt 512 ]];
                then
                        chop="cat"
                fi
                if [[ "$4" == "--raw" ]];
                then
                        dd if=$mem bs=1 skip=$(($2)) count=$(($arg3)) status=none | $chop
                else
                        dd if=$mem bs=1 skip=$(($2)) count=$(($arg3)) status=none | hexdump -Cv | $chop
                fi
        ;;
        vl | valist )
                pmap $2 | tail -n +2 | nl -b "p^[0-9a-z]"
        ;;
        vp | vaput )
                # $2 = pid
                # $3 = pageindex
                # $4 = offset
                # $5 = string/stdin

                data=${@:5}
                len=$(getlen "$data")
                offset=$4
                table=$(lsvaddr $2)
                lines=$(echo "$table" | wc -l)
                if [[ $3 -lt 1 ]] || [[ $3 -gt lines ]];
                then
                        echo -e "out of index: $3"
                        exit 4
                fi
                if [[ -z $offset ]];
                then
                        echo -e "OFFSET is not given"
                        exit 5
                fi
                addr=$((0x$(echo "$table" | sed "$3p;d")+$4))
                if [[ -z $data ]];
                then
                        echo -e "Reading from stdin.."
                        data=$(cat /dev/stdin)
                        len=$(getlen "$data")
                fi
                echo -e "$data" | writeat /proc/$2/mem $addr $len
                echo -e "payload has been written"
        ;;
        vs | vaset )
                addr=$(lsvaddr $2 | sed "$(($3))p;d")
                addr=$((0x$addr+$4))
                size=$(($5))
                char=$(($6))
                if [[ $size == 0 ]];
                then
                        echo -e "please specify SIZE(or not zero)"
                        exit 6
                fi
                if [[ $char -lt 0 ]] || [[ $char -gt 255 ]];
                then
                        echo -e "exceeding range(0 <= VALUE < 256)"
                        exit 7
                fi
                char=$(printf "%x" $char)
                perl -E 'say "\x'$char'"x'$size | writeat /proc/$2/mem $addr $size
                echo -e "success"
        ;;
        vg | vaget )
                addr=$(lsvaddr $2 | sed "$(($3))p;d")
                addr=$((0x$addr+$(($4))))
                len=$(($5))
                flag="cat"
                [[ $len == 0 ]] && len=256
                [[ $len -gt 512 ]] && flag="less"
                if [[ "$6" == "--raw" ]];
                then
                        dd if=/proc/$2/mem bs=1 skip=$addr count=$len status=none | $flag
                else
                        dd if=/proc/$2/mem bs=1 skip=$addr count=$len status=none | hexdump -Cv | $flag
                fi
        ;;
        memsize | ms )
                out=$(lsmem --summary=never -n -o RANGE | tail -n1 | cut -d'-' -f2)
                echo -e "[physical memory size]"
                echo -e "$out = $(($out)) bytes"
        ;;
        reference | ref )
                echo -e "/dev/mem\tphysical address"
                echo -e "/proc/iomem\tscheme of /dev/mem"
                echo -e "/proc/<PID>/maps\tPID's virtual memory address list"
                echo -e "/proc/<PID>/pagemap\tmapping between virtual and physical address"
                echo -e "/proc/<PID>/mem\t"
        ;;
        * )
                echo -e "USAGE: memhack [ACTION] [ARGS]..."
                echo -e "\tACTIONS"
                echo -e "=== PHYSICAL ==="
                echo -e "\tput | p\t\t[OFFSET] [STRING=STDIN], STRING: supports string escape"
                echo -e "\tset | s\t\t[OFFSET] [SIZE] [VALUE=0], 0 <= VALUE < 256"
                echo -e "\tget | g\t\t[OFFSET] [LENGTH=256] [--raw]?"
                echo -e "\n=== VIRTUAL ==="
                echo -e "\tvl | valist\t[PID], get virtual address list of PID"
                echo -e "\tvp | vaput\t[PID] [PAGEINDEX] [OFFSET] [STRING=STDIN],\n"\
                        "\t\t\t\tPAGEINDEX: a number to put some payload, on valist"
                echo -e "\tvs | vaset\t[PID] [PAGEINDEX] [OFFSET] [SIZE] [VALUE=0]"
                echo -e "\tvg | vaget\t[PID] [PAGEINDEX] [OFFSET] [LENGTH=256] [--raw]?"
                echo -e "\n=== INFORMATION ==="
                echo -e "\tmemsize | ms"
                echo -e "\treference | ref"
        ;;
esac

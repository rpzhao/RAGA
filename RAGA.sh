#!/bin/bash

######################################################################
## File Name: RAGA.sh (Thu Jan 10 09:30:00 2024);
######################################################################
set -o nounset
#bak=$IFS
#IFS=$'\n'


######################################################################
## Parameter;
######################################################################
ref=""  
ccs=""  
out="RAGA"  
thr="1"  
npr="3"  
dfi="90"  
dfl="20000"  
per="0.9"  
PER="0.5"
hep=""  
ver=""  
while [[ $# -gt 0 ]]
do
	key="$1"
	case "$key" in
		-r)
		ref="$2"
		shift
		shift
		;;
		-c)
		ccs="$2"
		shift
		shift
		;;
		-o)
		out="$2"
		shift
		shift
		;;
		-t)
		thr="$2"
		shift
		shift
		;;
		-n)
		npr="$2"
		shift
		shift
		;;
		-i)
		dfi="$2"
		shift
		shift
		;;
		-l)
		dfl="$2"
		shift
		shift
		;;
		-p)
		per="$2"
		shift
		shift
		;;
		-P)
		PER="$2"
		shift
		shift
		;;
		-h|-help)
		hep="help"
		shift
		;;
		-v|-version)
		ver="version"
		shift
		;;
		*)
		echo "Sorry, the parameter you provided does not exist."
		shift
		exit
		;;
	esac
done

######################################################################
## An introduction to how to use this software;
######################################################################
if [ "$hep" == "help" ]; then
	echo "Usage: RAGA-same.sh [-r reference genome] [-q source assembly] [-c source PacBio HiFi reads] [options]
Options:
	Input/Output:
	-r          reference genome
	-c          source PacBio HiFi reads
	-o          output directory

	Polish:
	-n INT      number of Polishing Rounds [>=3], default 3

	Filter:
	-i FLOAT    set the minimum alignment identity [0, 100], default 90
	-l INT      set the minimum alignment length, default 20,000
	-p FLOAT    extract the source PacBio HiFi read which align length is >= *% of its own length [0-1], default 0.9
	-P FLOAT    extract the source longAlt read which align length is >= *% of its own length [0-1), default 0.5

	Supp:
	-t INT      number of threads, default 1
	-v|-version show version number
	-h|-help    show help information

See more information at https://github.com/wzxie/RAGA.
	"
	exit 1

elif [ "$ver" == "version" ]; then
	echo "Version: 1.0.0"
	exit 1

else
	[[ $ref == "" ]] && echo -e "ERROR: path to reference genome not found, assign using -r." && exit 1
	[[ $ccs == "" ]] && echo -e "ERROR: path to source PacBio HiFi reads not found, assign using -c." && exit 1
	[[ $npr -lt 3 ]] && echo -e "ERROR: -n INT	number of Polishing Rounds [>=3], default 3." && exit 1
	([[ $dfi -lt 0 ]] || [[ $dfi -gt 100 ]]) && echo -e "ERROR: -i FLOAT	set the minimum alignment identity [0, 100], default 90." && exit 1
fi

######################################################################
## Check other scripts if they are found in path;
######################################################################
echo -e "Verifying the availability of related dependencies!"
for scr in minimap2 racon ragtag.py nucmer delta-filter show-coords awk hifiasm samtools seqkit
do
	check=$(command -v $scr)
	if [ "$check" == "" ]; then
		echo -e "\tERROR: command $scr is NOT in you PATH. Please check."
		exit 1
	else
		echo -e "\t$scr is ok"
	fi
done
echo -e "All dependencies have been checked.\n"

#=====================================================================
## step0: file name parser
#=====================================================================
refbase1=$(basename $ref)
ccsbase1=$(basename $ccs)
refbase2=${refbase1%.*}
ccsbase2=${ccsbase1%.*}

if [ -e $ccsbase1 ]; then
	cm=no
else
	ln -s $ccs $ccsbase1
	cm=yes
fi

################################################################################################
##step1:run hifiasm

hifiasm -t $thr --primary -o contigs $ccsbase1
awk '/^S/{print ">"$2;print $3}' contigs.*p_ctg.gfa > contigs.fa
mkdir contigs-tmp
mv contigs.*.gfa contigs-tmp
mv contigs.*.bed contigs-tmp
mv contigs.*.bin contigs-tmp

################################################################################################
##step2:long sequences make
bash same.sh -r $ref -q contigs.fa -c $ccs -o $out -n $npr -i $dfi -l $dfl -p $per -P $PER -t $thr

################################################################################################
###step3:RAGA Optimized Assembly (hifi&ont)
hifiasm -t $thr --primary -o RAGA-optimized --ul ./$out/longAlt_sur.fa $ccsbase1
awk '/^S/{print ">"$2;print $3}' RAGA-optimized.*p_ctg.gfa > optimized.fa
mkdir optimized-tmp
mv RAGA-optimized.*.gfa optimized-tmp
mv RAGA-optimized.*.bed optimized-tmp
mv RAGA-optimized.*.bin optimized-tmp
###############################################################################################
###step4:scaffolds base reference
ragtag.py scaffold -o $out-scaffolds $ref optimized.fa
ln -s ./$out-scaffolds/ragtag.scaffold.fasta $out-scaffolds.fa




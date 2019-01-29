#!/bin/bash
DATE=`date +%Y%m%d`
begdir='/nfs/DataVolume/Common/WildlifeCamera'
echo "Rename ALL files with prefix of current date"
dirs=`find $begdir -type d`
for d in $dirs; do
	cd $d
	for f in *; do
		if [[ -f $f ]]; then
			stat=$(stat -c %y $f)
			md=${stat:0:10} 
			md="${md//-}"	
			chrs=${#f}	
			if [ $chrs -lt 21 ] ; then
				nf="$md-$f"	
			else
			  	fn=${f:0:8}
				fd=${f:9:8}
				fx=${f:17}
				nf="$fd-$fn$fx"
			fi
			mv "$f" "$nf"
			echo "Dir=$d, Before=$f, After=$nf"
		else
			echo "Dir=$d, Skipped $f - not a file"
		fi
		done
	done
cd ~


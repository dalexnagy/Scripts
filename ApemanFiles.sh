#!/bin/bash
# 2018-07-12: Use file create date in rename step
#DATE=`date +%Y%m%d`
#
for i in {100..105} 
do
	path="/media/dave/SD-FAT32/DCIM/"$i"MEDIA"
	if [ -d $path ]; then
		if [ -z "$(ls -A $path)" ]; then
			echo "$path -- FOUND but EMPTY"
		else
			echo "$path -- FOUND with contents"
			echo "SETCD - Set current directory to ApeMan media - $path"
			cd $path
			#
			echo "RENAME - Rename all files to have prefix of file create date"
			for F in * ; do 
				FPref=${F:0:4}
				if [ "$FPref" = "IMAG" ]; then
					CDATE=$(stat -c %y $F)
					CDATE=${CDATE%% *}
					DATE=${CDATE:0:4}${CDATE:5:2}${CDATE:8:2}
			#		echo $F renamed to $DATE-$F
					mv "$F" "$DATE-$F" ;
				else 
					echo $F was NOT renamed
				fi
			done
			#
			echo "BROWSE-JPG - Browse JPG media files - Take note of those to be copied"
			feh -g1280x960 *.JPG
			#eog --disable-gallery *.JPG
			dialog --title "JPG File Review" --msgbox "\nNote JPG media files to copy" 8 24
			#read -p "Press any key to continue" -n1 
			#
			echo "BROWSE-AVI - Browse AVI media files - Take note of those to be copied"
			vlc --quiet *.AVI
			dialog --title "AVI Video Review" --msgbox "\nNote AVI media files to copy" 8 24
			#read -p "Press any key to continue" -n1 
			#
			dialog --title "Copy Files Now" --msgbox "\nCOPY files as desired in File Manager" 8 24
			#echo "COPY (offline) files as desired....Come back here when completed"
			#
			#read -p "Press any key to delete all files on ApeMan media.. " -n1
			rm $path/*.*
			#
			cd ~
			dfcmd=$(df /media/dave/SD-FAT32 | grep -v Filesystem)
			dfdev=${dfcmd%% *}
		fi
	else
		echo "/media/dave/SD-FAT32/DCIM/"$i"MEDIA -- Not Found"

	fi
done
#
echo "UNMOUNT media at $dfdev"
udisksctl unmount --block-device $dfdev
#echo "REMOVE the media"
dialog --title "Remove Media" --msgbox "\nUnmount & Remove Media at\n$dfdev" 8 24
#read -p "Press any key to continue " -n1
#
echo "CONVERT AVIs to MP4s"
cd /nfs/DataVolume/Common/WildlifeCamera
find . -depth -name "*.AVI" 
find . -depth -name "*.AVI" -exec sh -c 'avconv -i "$1" -c:v libx264 "${1%.AVI}.mp4"' _ {} \;
find . -depth -name "*.AVI" -exec rm {} \;
echo "DONE!"
exit


## declare an array variable
declare -a months=("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")

path="/media/dave/DATA/Documents/Financial/PayPal/2018"
cd $path
#
echo "RENAME - Rename all files to yyyy-mm-statement in $path"
for F in * ; do
	FMon=${F:10:3} # Month
	FYear=${F:14:4} # Year
	## now loop through the array
	arrayCtr=1
	for i in "${months[@]}"; do
   		if [ "$FMon" = "$i" ]; then
   			monthNum=$(printf "%02d" $arrayCtr)
   			echo "$F renamed to $FYear-$monthNum-statement.pdf"
#   			mv "$F" "$FYear-$monthNum-statement.pdf" ;
   			break;
		fi
		((arrayCtr++))
	done
done


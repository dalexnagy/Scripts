package LogRoutines;
#
# LogRoutines.pm - Log management and analysis routines.
# To use:
#		1.	Use use lib "<where this is located>";
# 	2. 	Use LogRoutines;
#		3. 	my (ret1, ret2, ...) = LogRoutines::subroutine_name(params);
#
#------------------ CHANGE LOG -------------------------------------------------
# 04/10/2013	New 
# 04/23/2013	Fixed bug in error counting routine.
# 04/25/2013	Added code to count errors more completely
# 04/26/2013	Added code to write error info to MySQL database
# 05/22/2013	Fixed bug that ignored first error message found.
# 06/05/2013	(1) Changed code to check for total bytes
#				(2) Converted some common code to a function call
#				(3) Set defaults for MBSent & MBTotal (if not found in log)
#				(4)	Added code to not write error messages if error log file name is empty
# 06/09/2013	Modified code to search for total size value & remove unneeded characters
# 01/07/2015	Changed variables to always be init within subs
# 11/27/2018	Modifled LogAnalysis Routine to open, write, & close error log file. Removed subroutine that used to do this.
#
#-------------------------------------------------------------------------------
use strict;
use File::Copy qw( move );

#--------------------- GLOBAL VARIABLES ----------------------------------------
my $ErrMsgs;
#--------------------- END OF GLOBAL VARIABLES ---------------------------------
 

sub LogDelete {
#-----------------------------------------------------------
# Search the given directory for specified files.
# Delete files over a specified age in days. 
#-----------------------------------------------------------

# Requires:
#  0 = directory
#  1 = suffix to manage (ie, 'log')
#  2 = age (if order than this, delete)
#  3 = 'v' if messages for each file deleted
#
# Returns
#  0 = Number of files found
#	 1 = Number of files delete
#  2 = Total bytes found in all files
#  3 = Total bytes in files deleted

	my $Files = 0;
	my $Deletes = 0;
	my $TotalBytes = 0;
	my $DeletedBytes = 0;

	chdir $_[0];
	while (my $next = <*.$_[1]>) {

		my $mtime=(stat($next))[9];
		my $size=(stat($next))[7];
	
		$TotalBytes += $size;
		++$Files;
	
		my $ageDays = (time - $mtime)/(60*60*24);
	
		# Only act on files over a certain age
		if ($ageDays > $_[2]) {
			unlink $next;
			++$Deletes;
			$DeletedBytes += $size;
			if ($_[3] eq "v") {
				print "  '$next' deleted - it was ".sprintf "%.1f",$ageDays;
				print " days old.\n";
				}
			}
		}
	return ($Files, $Deletes, $TotalBytes, $DeletedBytes); 
}

sub LogArchive {
#-----------------------------------------------------------
# Search the directory for specific files, then rename and move them
#-----------------------------------------------------------

# Requires:
#  0 = directory to search
#  1 = suffix to manage (ie, 'log')
#  2 = archive directory
#  3 = 'v' if messages for each file deleted
#
# Returns
#  0 = Number of files renamed
#  1 = Number of files moved

	my $Files=0;
	my $Renames=0;
	my $Moves=0;

	chdir $_[0];
	while (my $next = <*.$_[1]>) {
		my $mtime = (stat($next))[9];
		my $size = (stat($next))[7];
		
		++$Files;

		# Create new file name suffix (will be inserted before the '.log')
		my $yy = (localtime($mtime))[5]+1900;
		my $mm = (localtime($mtime))[4]+1;
		my $dd = (localtime($mtime))[3];
		my $hr = (localtime($mtime))[2];
		my $mn	=	(localtime($mtime))[1]; 
		my $se	=	(localtime($mtime))[0];

		if (length($mm) == 1) {$mm = "0".$mm}
		if (length($dd) == 1) {$dd = "0".$dd}
		if (length($mn) == 1) {$mn = "0".$mn}
		if (length($hr) == 1) {$hr = "0".$hr}
		if (length($se) == 1) {$se = "0".$se}

		my $dateString = $yy.$mm.$dd."-".$hr.$mn.$se;
	
		my $newName = substr($next,0,index($next,".$_[1]"))."_".$dateString.".$_[1]";
		rename $next, $newName;
		++$Renames;
		if ($_[3] eq "v" ) {
			print "  '$next' -> '$newName'\n";
			}
		move $newName, $_[2] or die "Unable to move $next->$_[2]: $!";
		if ($_[3] eq "v" ) {
			print "    Moved '$newName'.\n";
			}
		++$Moves;
		}

return $Renames, $Moves;
}

sub LogAnalysis {
#-----------------------------------------------------------
# Analyze RSYNC logs.  Report back number of files copied, 
# deleted, number of error messages, MB sent, Total MB of backup
# If errors are found, messages are extracted to separate file
#-----------------------------------------------------------

# Requires:
#  0 = log file name
#  1 = file name for extracted error messages (if empty, not done)
#  2 = 'v' for messages 
#
# Returns
#  0 = Number of files copied
#  1 = Number of files deleted
#  2 = Number of error messages
#  3 = Number of MB sent
#  4 = Total size in MB
	
	my $errorMsgs=0;
	my $filesCopied=0;
	my $filesDeleted=0;
	my $MBSent=0;
	my $MBTotal=0;

	open(LogFile1, $_[0]) or die "LogAnalysis: Could not open file '$_[0]' $!";
	while(<LogFile1>)
	{
	  my($line) = $_;
 		chomp($line);
 		if (substr($line,index($line,"] ")+2,6) eq "rsync:") {
			if ($errorMsgs == 0) {
				open($ErrMsgs, '>>', $_[1]) or die "LogAnalysis::LogAnalysis: Could not open file '$_[1]' $!";
				print $ErrMsgs "RSYNC Error Messages found in Log file\n\n";
				}
			print $ErrMsgs $line."\n";
			++$errorMsgs;

		}
 		if (substr($line,index($line,"] ")+2,2) eq ">f") {
			++$filesCopied;
		}
 		if (substr($line,index($line,"] ")+2,4) eq "*del") {
			++$filesDeleted;
		}
 		if (index($line," sent ") > 0) {
			my $NumberStart = index($line,"sent")+4;
			my $NumberEnd = index($line," bytes", $NumberStart);
			my $aNumberString = substr($line, $NumberStart, $NumberEnd-$NumberStart);
			$MBSent = ConvNumber($aNumberString);
		}

 		if (index($line,"total size ") > 0) {
#			print "line=$line\n";
			$line =~ s/ is//;
			my $NumberStart = index($line,"size ")+5;
			my $NumberEnd = length($line);
			if (index($line,"  speedup") > 0) {
				$NumberEnd = index($line,"  speedup", $NumberStart);
				}
			my $aNumberString = substr($line, $NumberStart, $NumberEnd-$NumberStart);
			$MBTotal = ConvNumber($aNumberString);
		}
	}
	if ($errorMsgs > 1) {
		print $ErrMsgs "\nEnd of RSYNC Error Messages found in Log file -- $errorMsgs Errors Found";
		close $ErrMsgs;
		}

	return ($filesCopied, $filesDeleted, $errorMsgs, $MBSent, $MBTotal);
}

#----------------------------------------------------------------
sub LogErrorCounts {
# Open log file and count errors by error text and number 

# Requires:
#	0 = System name	
#	1 = file name for extracted error messages
#
# Returns
#  Nothing
#

use DBI;
use strict;

# Constants
my $server = "localhost";
my $db = "rsyncResults";

# Non-database-related variables
my $errMsgCtr = 0;  #Total number of messages
my $errMsgUniqueCtr = 0; #Number of unique messages found
my $errMsgText = 0;  #First value =  text of message
my $errMsgTextCtr = 1; #Second value = count of these messages
my @errMsgs;  #Array for messages and counters
my $errMsgFound = 0; #Set to 1 if we found a message

# Connect to MYSQL 
my $dbh = DBI->connect("DBI:mysql:host=".$server.";database=".$db,"guest","",{RaiseError=>1}) or die "Failed to Connect!  $DBI::errstr";
# Prepare the SQL query
my $insert = $dbh->prepare_cached("INSERT INTO Errors (SystemName, MsgDate, MsgTime, Operation, Object, Error) 
			Values (?, ?, ?, ?, ?, ?)");

	open(LogErrors, $_[1]) or die "LogErrorCounts: Could not open file '$_[1]' $!";
	while(<LogErrors>) 	{
		my($line) = $_;
		chomp($line);
		$errMsgFound = 0;

		my $msgDate = substr($line,0,10);
		my $msgTime = substr($line,11,8);
		my $newStart = index($line," rsync: ");

		if ($newStart > 0) {
			$newStart+=7;
			my $rsyncOper = substr($line,$newStart+1,(index($line,'"',$newStart)-$newStart));
			$newStart+=length($rsyncOper);
			$rsyncOper = substr($rsyncOper,0,length($rsyncOper)-2);
			
			my $rsyncObjectStart = index($line,'"',$newStart)+1;
			my $rsyncObjectEnd = index($line,'"',$rsyncObjectStart+1);
			my $rsyncObject = substr($line,$rsyncObjectStart,$rsyncObjectEnd-$rsyncObjectStart);

			my $msgStart = index($line,": ",$newStart);

			if ($msgStart > 0) {
				$msgStart+=2;
				my $rsyncError = substr($line, $msgStart);
				my $errMsgString = $rsyncOper." - ".$rsyncError;
				++$errMsgCtr;

				# Insert record into database
				my $success = 1;
        $success &&= $insert->execute($_[0], $msgDate, $msgTime, $rsyncOper, $rsyncObject, $rsyncError);
				if (!$success) {
					print "Database Insert FAILED with MySQL error: ".$dbh->errstr;
						}

				# Now look in array: Did we see this error before?
				for (my $i=0; $i<$errMsgUniqueCtr; $i++) {
					if ($errMsgs[$i][$errMsgText] eq $errMsgString) { # Yes..update counter
						++$errMsgs[$i][$errMsgTextCtr];
						$errMsgFound = 1;
						last;
						}
					}
				if ($errMsgFound == 0) {	#No...Add to array
					$errMsgs[$errMsgUniqueCtr][$errMsgText] = $errMsgString;
					$errMsgs[$errMsgUniqueCtr][$errMsgTextCtr] = 1;
					++$errMsgUniqueCtr;
					}
				}
			}
		}
	print "  Found the following error(s):\n";
	for (my $i=0; $i<$errMsgUniqueCtr; $i++) {
		print "    Failure: '$errMsgs[$i][$errMsgText]', Count: $errMsgs[$i][$errMsgTextCtr]\n";
		}

	close LogErrors; # Close input file
	$insert->finish; # Close database link
	$dbh->disconnect; # Disconnect from MySQL
}

#----------------------------------------------------------------
# Convert Date & time to MM/DD/YYYY @ HH:MI:SS
sub ConvTime
{
	my($sec,$min,$hr,$mday,$mon,$yr,$wday,$yday,$isdst) = localtime($_[0]);
	$yr += 1900;
	++$mon;
	if (length($sec) == 1) {$sec = "0".$sec};
	if (length($min) == 1) {$min = "0".$min};
	if (length($hr) == 1) {$hr = "0".$hr};
	if (length($mon) == 1) {$mon = "0".$mon};
	if (length($mday) == 1) {$mday = "0".$mday};
	return $mon."/".$mday."/".$yr." @ ".$hr.":".$min.":".$sec;
}
#----------------------------------------------------------------
# Convert date & time to YYYY-MM-DD HH:MM:SS for MySQL
sub ConvDateTimeMySQL
{
	my($sec,$min,$hr,$mday,$mon,$yr,$wday,$yday,$isdst) = localtime($_[0]);
	$yr += 1900;
	++$mon;
	if (length($sec) == 1) {$sec = "0".$sec};
	if (length($min) == 1) {$min = "0".$min};
	if (length($hr) == 1) {$hr = "0".$hr};
	if (length($mon) == 1) {$mon = "0".$mon};
	if (length($mday) == 1) {$mday = "0".$mday};
	return $yr."-".$mon."-".$mday." ".$hr.":".$min.":".$sec;
}


#----------------------------------------------------------------
# Convert number to MB
sub ConvNumber
{
	my $aNumberString=$_[0];
	$aNumberString=~s/\D//g;
	my $MB = sprintf("%.1f", $aNumberString/1000000);
	$MB =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
	return $MB;
}

#----------------------------------------------------------------
# Next stmt ("1") required by Perl
1;


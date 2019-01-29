#! /usr/bin/perl
#
# DailyBackup.pl - Script to backup files on my laptop	
#		with RSYNC, archive logs, and email results.
#
#------------------ CHANGE LOG -------------------------------------------------
# 09/24/2012 New 
# 01/23/2017 (1)	Changed external (portable) drive name and folders 
#			 (2)	Changed rsynch routine to use common exclude file
# 03/21/2017 Changed all instances of SHARED to DATA
# 10/10/2018 Added message in RSYNC step with name of log file for RSYNC messages
# 10/11/2018 Move message added 10/10 to calling routine
# 11/23/2018 Changed destination for home backup	

#-------------------------------------------------------------------------------
use DBI;
use strict;
use File::Copy qw( move );

# Get host name
use Sys::Hostname;
my $host = hostname;

#------------------------ CONSTANTS ------------------------

# $LogDir is the directory containing the log files
my $LogDir = "/home/dave/Logs";

# $LogArchiveDir is the directory containing the archived log files
my $LogArchiveDir = "/home/dave/Logs/Archive";

# $MySQLBackupDir is the directory for MySQL backup SQL files
my $MySQLBackupDir = "/home/dave/MySQL_Backup";

# $LogArchiveAge is the number of days to let a log file age before deletion
my $LogArchiveAge = 3.0;

# Arrays that hold source dirs/devs, destination, and log file names
my @Source = ("/home/dave/",
	"/media/dave/DATA/");
my @Destination = ("/media/dave/Home-Backup/",
	"/media/dave/DavesPC-Backup/DATA");
my @Log = ("$LogDir/rsync-backup-Port-Backup-dave.log",
	"$LogDir/rsync-backup-Port-Backup-DATA.log");

# Size of the array (number of directories to backup)
my $BackupSteps = @Source;

# Step Number Counter
my $step_no = 1;

# Database-related variables
my $server = "localhost";
my $db = "information_schema";
#--------------------- MISC VARIABLES ------------------------------------------
my ($rows, $dbsBackedUp);
my ($dbh, $sth);
my (@mysqlDB, $dbName);
my $LogFiles = 0;
my $LogTotalBytes = 0;
my $LogDeletes = 0;
my $LogDeletedBytes = 0;
my $LogRenames = 0;
my $LogMoves = 0;
my $LogTotalBytes = 0;
my $LogFiles = 0;
my $filesCopied = 0;
my $filesDeleted = 0;
my ($MBSent, $MBTotal);
my $mtime;
my $size;
my $ageDays;
my ($next, $newName);
my ($dateString, $yy, $mm, $dd, $hr, $mn, $se);
my ($RSYNC_cmd, $MySQLBackup);
my $exitValue = 0;  #Initially set to 'successful'
#--------------------- END OF VARIABLES --------------------

# Preamble
print "\nDaily backup process started on system '$host' on ".ConvTime(time)."\n";
print "   via script '$0' (last updated on ".ConvTime((stat($0))[9]).")\n\n";

#-----------------------------------------------------------
# Search archive for files with a suffix of '.log' 
# older than days in $LogArchiveAge variable and delete
# Not used to determine overall success or failure.
#-----------------------------------------------------------

print "Step $step_no: Delete old log files in '$LogArchiveDir' over $LogArchiveAge days old.\n";

chdir $LogArchiveDir;
while ($next = <*.log>) {

	$mtime=(stat($next))[9];
	$size=(stat($next))[7];
	
	$LogTotalBytes += $size;
	++$LogFiles;
	
	$ageDays = (time - $mtime)/(60*60*24);
	
	# Only act on files over a certain age
	if ($ageDays > $LogArchiveAge) {
	  unlink $next;
		++$LogDeletes;
		$LogDeletedBytes += $size;
		print "  '$next' deleted - it was ".sprintf "%.1f",$ageDays;
		print " days old.\n";
		}
	}
$LogTotalBytes=sprintf("%6.1d", int($LogTotalBytes/1024));
$LogDeletedBytes=sprintf("%6.1d", int($LogDeletedBytes/1024));
print "End Step $step_no: $LogTotalBytes KB found in $LogFiles file(s) - $LogDeletes deleted, freeing $LogDeletedBytes KB.\n\n";
$step_no++;

#-----------------------------------------------------------
# Search the 'Log' Directory for '.log' files, then rename and move them
# Not used to determine overall success or failure. 
#-----------------------------------------------------------

print "Step $step_no: Rename log files in '$LogDir' and move to '$LogArchiveDir'\n";


chdir $LogDir;
while ($next = <*.log>) {
	$mtime=(stat($next))[9];
	$size = (stat($next))[7];
		
	$LogTotalBytes += $size;
	++$LogFiles;

	# Create new file name suffix (will be inserted before the '.log')
	$yy = (localtime($mtime))[5]+1900;
	$mm = (localtime($mtime))[4]+1;
	$dd = (localtime($mtime))[3];
	$hr = (localtime($mtime))[2];
	$mn	=	(localtime($mtime))[1]; 
	$se	=	(localtime($mtime))[0];

	if (length($mm) == 1) {$mm = "0".$mm}
	if (length($dd) == 1) {$dd = "0".$dd}
	if (length($mn) == 1) {$mn = "0".$mn}
	if (length($hr) == 1) {$hr = "0".$hr}
	if (length($se) == 1) {$se = "0".$se}

	$dateString = $yy.$mm.$dd."-".$hr.$mn.$se;
	
	$newName = substr($next,0,index($next,'.log'))."_".$dateString.".log";
	rename $next, $newName;
	++$LogRenames;
	print "  '$next' -> '$newName'\n";
	move $newName, $LogArchiveDir or die "Unable to move $next->$LogArchiveDir: $!";
	print "    Moved '$newName'.\n";
	++$LogMoves;
	}

$LogTotalBytes=sprintf("%6.1d", int($LogTotalBytes/1024));
print "End Step $step_no: $LogRenames files(s) renamed and $LogMoves file(s) moved.\n\n";
$step_no++;

#-----------------------------------------------------------
# Backup all production MYSQL databases.
# Failure here will cause message to say 'Failed'
#-----------------------------------------------------------
print "Begin Step $step_no: Backup all MySQL tables.\n";

# Connect to MYSQL 
$dbh = DBI->connect("DBI:mysql:host=".$server.";database=".$db,"guest","",{RaiseError=>1}) or die "Failed to Connect!  $DBI::errstr";
$sth = $dbh->prepare("SELECT SCHEMA_NAME AS `Database` 
	FROM INFORMATION_SCHEMA.SCHEMATA 
	WHERE ((SCHEMA_NAME != 'mysql') AND (SCHEMA_NAME NOT LIKE '%_schema'))
	ORDER by SCHEMA_NAME");$sth->execute();
$rows = $sth->rows();

if ($rows == 0) {
	print "** Query did not find anything.\n\n";
	}
else {
	$dbsBackedUp = 0;
	while($dbName = $sth->fetchrow_array()) {
		if ($dbName ne 'information_schema') {
			print "  MySQL $dbName database backup ";
			$MySQLBackup = "mysqldump -u backup $dbName > $MySQLBackupDir/$dbName.sql";
			if (system ($MySQLBackup)==0) {
				print "was successful!\n";
				$dbsBackedUp++;
				}
				else {
				print "FAILED!\n";
				$exitValue = 1; #Set overall indicator to 'failure'
				}
			}
		}
	}

$sth->finish;
$dbh->disconnect;

print "End Step $step_no: MySQL backup completed for $dbsBackedUp databases.\n\n";
++$step_no;

#-----------------------------------------------------------
# Use RSYNC to do incremental backups to Falcon server.
# Failure here will cause message to say 'Failed'
#-----------------------------------------------------------
print "Step $step_no: Do incremental backups using RSYNC.\n";

for(my $i=0;$i<$BackupSteps;$i++)
	{
	print "  Starting RSYNC of files in @Source[$i] at ".ConvTime(time)."\n";
	my ($copied, $deleted, $Sent, $Total) = RsyncBackup(@Source[$i], @Destination[$i], @Log[$i]);
	print "  $copied files copied, $deleted deleted.";
	if ($copied > 0) {
		print "\n      ".$Sent."MB sent.  Total size is ".$Total."MB.\n";
		}
	print "  See messages in: ".@Log[$i]."\n";	
  }

print "End Step $step_no: $BackupSteps incremental backup processes attempted.\n\n";

#-----------------------------------------------------

print "Daily backup process completed in $step_no steps at: ".ConvTime(time)."\n";
exit $exitValue;  # Use whatever final setting of success/failure

#----------------------------------------------------------------
# Subroutines/Functions
#----------------------------------------------------------------
# Do RSYNC command
sub RsyncBackup 
{
	$RSYNC_cmd = "rsync -aqhi --delete --log-file='$_[2]' --exclude-from='/home/dave/backups-exclude.txt' $_[0] $_[1]";
	if (system ($RSYNC_cmd)==0) {
		print "    Backup successful on ".ConvTime(time)." - ";
		}
		else {
		print "  **Backup FAILED on ".ConvTime(time)."!\n\n";
		$exitValue = 1; #Set overall indicator to 'failure'
		}

	open(LogFile1, $_[2]);
	while(<LogFile1>)
	{
	  my($line) = $_;
 		chomp($line);
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
			$aNumberString=~s/\D//g;
			$MBSent = sprintf("%.1f", $aNumberString/1000000);
			$MBSent =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;

			my $NumberStart = index($line,"size")+4;
			my $aNumberString = substr($line, $NumberStart, 16);
			$aNumberString=~s/\D//g;
			$MBTotal = sprintf("%.1f", $aNumberString/1000000);
			$MBTotal =~ s/(\d)(?=(\d{3})+(\D|$))/$1\,/g;
		}
	}
	return ($filesCopied, $filesDeleted, $MBSent, $MBTotal);
}

#----------------------------------------------------------------
# Convert time to MM/DD/YYYY @ HH:MI:SS
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


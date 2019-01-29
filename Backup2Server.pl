#! /usr/bin/perl
#
# DailyBackup.pl - Script to backup files on my laptop	
#		with RSYNC, archive logs, and email results.
#
#------------------ CHANGE LOG -------------------------------------------------
# 08/04/2011	New 
#	08/08/2011	Minor fixes.
# 08/09/2011	Changed archive days to 5
# 08/10/2011	(1) Added code to report number of files copied
#							(2) Changed to use arrays for source, destination, and log file names
# 08/11/2011	Minor text change on a message.
# 08/12/2011	(1) Added routine to convert time and return normal-looking date & time
#							(2) Added code to look for "] " as beginning of area to look for flags
#							(3) Minor wording changes and consolidated code by combining functions
# 08/13/2011	Minor text changes; Changed log retention to 3 days.
# 08/14/2011	Removed file size from messages
# 08/15/2011	Change '/t' to 2 spaces, change 'renamed to' to '->'
# 08/16/2011	(1) Added line to add 1 to month number, 
#							(2) Reversed change to line combining sprintf and text
# 08/17/2011	Minor text change.
# 08/25/2011	Minor text changes and reformatting of messages.
# 10/13/2011	Added 'i' to RSYNC options
# 10/14/2011	Added code to count and report files deleted on destination.
# 10/18/2011	Added code to backup MySQL databases
#	10/20/2011	Minor text changes in messages
#	10/21/2011	(1) Added code to query MySQL for list of databases & changed code to use this list.
#							(2) Changed to strict variable declarations
# 01/25/2012	Added code to extract and show bytes sent and total bytes
# 04/29/2012	Added code to better report success and failure.
# 05/03/2012	Added code to not show MB copied & deleted if no files copied.
# 09/28/2012	(1) Changed user name for MySQL backups to 'backup'
#							(2) Change 'IF' in MySQL backup step to skip any '_schema' databases
#							(3) Minor text changes in messages
#	10/01/2012	(1) Changed destination for /home/dave to SHARED/Ubuntu_Home
#							(2) Minor text change in a message
#	10/02/2012	Minor text change in a message
#	10/04/2012	Minor text change in a message
# 01/31/2013	Minor text change in a message
# 02/04/2013	Added major code to manage MySQL backups in an archive directory
# 02/05/2013	(1) Minor correction to a variable name
#							(2)	Added file size MySQL backup archiving messages
# 02/15/2013	Changed from '.sql' to '.log' in log delete section (intro. in 2/4 changes)
# 04/12/2013	Changed to use 'LogRoutines' subroutines
# 04/16/2013	Changed to use one array for source, destination, log file, error msg file
#	04/22/2013	Added call to summarize errors found
# 07/25/2013	(1) Added code to show size of MySQL backup files on message
#							(2) Cleaned up MySQL backup code (removed 'if', added WHERE in SQL)
#							(3) Changed some 'sprintf' conversions from integer (d) to floating (f)
# 12/09/2014	Modified for new computer
# 12/11/2014	Changed log and error file names
# 12/12/2014	Changed exclude list file name
# 01/01/2015	Added entry in 'Candidates' array to backup native Win7 'Documents and Settings' for user 'dave'
# 01/17/2015	Changed names of log files
# 04/28/2015	Added exit(0).
# 06/02/2016	Changed 'lib' reference due to changes in folder structures.
# 02/23/2017	Modifications to basic program for laptop (parms only)
# 03/20/2017	(1) Changed from 'Daves_Laptop' to 'DavesLaptop'
#				(2) Added /nfs/ to prefix of DataVolume
# 04/05/2017	(1) Added host name to backup directories on server by using $host variable
#				(2)	Added step to backup xpad entries to folder in my home
# 10/10/2018	Added message in RSYNC step with name of log file for RSYNC messages
# 10/11/2018	Moved message added 10/10 to calling routine	
# 10/12/2018	Fixed syntax errors in code I moved 10/11
# 11/23/2018	Changed back of my home directory to separate directory on server
# 
#
#-------------------------------------------------------------------------------
use DBI;
use strict;
use File::Copy qw( move );
use lib "/home/dave/Perl/Backups";
use LogRoutines;

# Get host name
use Sys::Hostname;
my $host = hostname;

#------------------------ CONSTANTS ------------------------

# $LogDir is the directory containing the log files
my $LogDir = "/home/dave/Logs";
# $LogArchiveDir is the directory containing the archived log files
my $LogArchiveDir = "/home/dave/Logs/Archive";
# $LogArchiveAge is the number of days to let a log file age before deletion
my $LogArchiveAge = 3.0;

# $MySQLBackupDir is the directory for MySQL backup SQL files
my $MySQLBackupDir = "/home/dave/MySQL_Backup";
# $MySQLBackupArchiveDir is the directory containing the archived log files
my $MySQLBackupArchiveDir = "/home/dave/MySQL_Backup/Archive";
# $MySQLBackupArchiveAge is the number of days to let a log file age before deletion
my $MySQLBackupArchiveAge = 30.0;

# Array to hold source dirs/devs, destination, log file names, and extracted error messages files
#my @Candidates = (["/home/dave/","/media/dave/DATA/Ubuntu_Home","$LogDir/rsync-backup-home2DATA.log","$LogDir/rsync-backup-home2DATA_ErrMsgs.log"],
#["/media/dave/DATA/","/nfs/DataVolume/$host/DATA","$LogDir/rsync-backup-DATA2server.log","$LogDir/rsync-backup-DATA2server_ErrMsgs.log"]);
my @Candidates = (["/home/dave/","/nfs/DataVolume/$host/dave","$LogDir/rsync-backup-dave2server.log","$LogDir/rsync-backup-dave2server_ErrMsgs.log"],
["/media/dave/DATA/","/nfs/DataVolume/$host/DATA","$LogDir/rsync-backup-DATA2server.log","$LogDir/rsync-backup-DATA2server_ErrMsgs.log"]);

# Size of the array (number of directories to backup)
my $BackupSteps = @Candidates;

# Step Number Counter
my $step_no = 1;

# Array positional values
my $posSource = 0;
my $posDestination = 1;
my $posLogFile = 2;
my $posErrMsgsFile = 3;

# Database-related variables
my $server = "localhost";
my $db = "information_schema";
#--------------------- MISC VARIABLES ------------------------------------------
my ($rows, $dbsBackedUp);
my ($dbh, $sth);
my (@mysqlDB, $dbName);
my $MySQLBackupFiles = 0;
my $MySQLBackupTotalBytes = 0;
my $MySQLBackupDeletes = 0;
my $MySQLBackupDeletedBytes = 0;
my $MySQLBackupRenames = 0;
my $MySQLBackupMoves = 0;
my $MySQLBackupTotalBytes = 0;
my $MySQLBackupFiles = 0;

my $LogTotalBytes = 0;
my $LogDeletes = 0;
my $LogDeletedBytes = 0;
my $LogRenames = 0;
my $LogMoves = 0;
my $LogFiles = 0;
my $ErrMsgs;

my $filesCopied = 0;
my $filesDeleted = 0;
my $errMsgs = 0;
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
print "\nDaily backup process started on system '$host' on ".LogRoutines::ConvTime(time)."\n";
print "   via script '$0' (last updated on ".LogRoutines::ConvTime((stat($0))[9]).")\n\n";

#-----------------------------------------------------------
# Search archive for files with a suffix of '.log' 
# older than days in $LogArchiveAge variable and delete
# Not used to determine overall success or failure.
#-----------------------------------------------------------

print "Step $step_no: Delete old log files in '$LogArchiveDir' over $LogArchiveAge days old.\n";

my ($LogFiles,$LogDeletes,$LogTotalBytes,$LogDeletedBytes) = LogRoutines::LogDelete($LogArchiveDir,"log",$LogArchiveAge,"v");

$LogTotalBytes=sprintf("%6.1f", int($LogTotalBytes/1024));
$LogDeletedBytes=sprintf("%6.1f", int($LogDeletedBytes/1024));
print "End Step $step_no: $LogTotalBytes KB found in $LogFiles file(s) - $LogDeletes deleted, freeing $LogDeletedBytes KB.\n\n";
$step_no++;

#-----------------------------------------------------------
# Search the 'Log' Directory for '.log' files, then rename and move them
# Not used to determine overall success or failure. 
#-----------------------------------------------------------

print "Step $step_no: Rename log files in '$LogDir' and move to '$LogArchiveDir'\n";

my ($LogRenames,$LogMoves) = LogRoutines::LogArchive($LogDir,"log",$LogArchiveDir,"v");

print "End Step $step_no: $LogRenames files(s) renamed and $LogMoves file(s) moved.\n\n";
$step_no++;

#-----------------------------------------------------------
# Search MySQL Backup archive for files with a suffix of '.sql' 
# older than days in $MySQLBackupArchiveAge variable and delete
# Not used to determine overall success or failure.
#-----------------------------------------------------------

print "Step $step_no: Delete old MySQL Backup files in '$MySQLBackupArchiveDir' over $MySQLBackupArchiveAge days old.\n";

my ($MySQLBackupFiles,$MySQLBackupDeletes,$MySQLBackupTotalBytes,$MySQLBackupDeletedBytes) = LogRoutines::LogDelete($MySQLBackupArchiveDir,"sql",$MySQLBackupArchiveAge,"v");

$MySQLBackupTotalBytes=sprintf("%6.1f", int($MySQLBackupTotalBytes/1024));
$MySQLBackupDeletedBytes=sprintf("%6.1f", int($MySQLBackupDeletedBytes/1024));
print "End Step $step_no: $MySQLBackupTotalBytes KB found in $MySQLBackupFiles file(s) - $MySQLBackupDeletes deleted, freeing $MySQLBackupDeletedBytes KB.\n\n";
$step_no++;

#-----------------------------------------------------------
# Search the 'MySQL Backup' Directory for '.sql' files, then rename and move them
# Not used to determine overall success or failure. 
#-----------------------------------------------------------

print "Step $step_no: Rename MySQL Backup files in '$MySQLBackupDir' and move to '$MySQLBackupArchiveDir'\n";

my ($MySQLBackupRenames,$MySQLBackupMoves) = LogRoutines::LogArchive($MySQLBackupDir,"sql",$MySQLBackupArchiveDir,"v");

print "End Step $step_no: $MySQLBackupRenames files(s) renamed and $MySQLBackupMoves file(s) moved.\n\n";
$step_no++;

#-----------------------------------------------------------
# Backup all production MYSQL databases.
# Failure here will cause message to say 'Failed'
#-----------------------------------------------------------
print "Begin Step $step_no: Backup all MySQL databases to '$MySQLBackupDir'.\n";

# Connect to MYSQL 
$dbh = DBI->connect("DBI:mysql:host=".$server.";database=".$db,"backup","",{RaiseError=>1}) or die "Failed to Connect!  $DBI::errstr";
$sth = $dbh->prepare("SELECT SCHEMA_NAME AS `Database` 
	FROM INFORMATION_SCHEMA.SCHEMATA 
	WHERE ((SCHEMA_NAME != 'mysql') AND (SCHEMA_NAME NOT LIKE '%_schema'))
	ORDER by SCHEMA_NAME");
$sth->execute();
$rows = $sth->rows();

if ($rows == 0) {
	print "** Query did not find anything.\n\n";
	}
else {
	$dbsBackedUp = 0;
	while($dbName = $sth->fetchrow_array()) {
		print "  '$dbName' database backup ";
		my $MySQLBackupFile = "$MySQLBackupDir/$dbName.sql";
		$MySQLBackup = "mysqldump -u backup $dbName > $MySQLBackupFile";
		if (system ($MySQLBackup)==0) {
			print "was successful! (".sprintf("%4.1f",(stat($MySQLBackupFile))[7]/1000)."Kb)\n";
			$dbsBackedUp++;
			}
			else {
			print "FAILED!\n";
			$exitValue = 1; #Set overall indicator to 'failure'
			}
		}
	}

$sth->finish;
$dbh->disconnect;

print "End Step $step_no: MySQL backup completed for $dbsBackedUp databases.\n\n";

++$step_no;
#-----------------------------------------------------------
# Use RSYNC to do a backup of the files in the xpad folder.
# Failure here will cause message to say 'Failed'
#-----------------------------------------------------------
print "Step $step_no: Do xpad backup using RSYNC.\n";

my $RSYNC_xpad_cmd = "rsync -aqhi --delete --log-file='$LogDir/xpad-backup.log' --exclude='server' /home/dave/.config/xpad/* /home/dave/xpad-backup";
	if (system ($RSYNC_xpad_cmd)==0) {
		print "    xpad backup successful on ".LogRoutines::ConvTime(time)."!\n";
		$exitValue = 0;
		}
		else {
		print "  **xpad backup FAILED on ".LogRoutines::ConvTime(time)."!\n\n";
		$exitValue = 1; #Set overall indicator to 'failure'
		}

print "End Step $step_no: xpad entries successfully copied.\n\n";
++$step_no;
#-----------------------------------------------------------
# Use RSYNC to do incremental backups to Falcon server.
# Failure here will cause message to say 'Failed'
#-----------------------------------------------------------
print "Step $step_no: Do incremental backups using RSYNC.\n";

for(my $i=0;$i<$BackupSteps;$i++)
	{

	print "  Start RSYNC of $Candidates[$i][$posSource] to $Candidates[$i][$posDestination] on ".LogRoutines::ConvTime(time)."\n";
	my ($copied, $deleted, $errorMsgs, $Sent, $Total) = RsyncBackup($Candidates[$i][$posSource], $Candidates[$i][$posDestination], $Candidates[$i][$posLogFile], $Candidates[$i][$posErrMsgsFile]);
	print "  $copied files copied, $deleted deleted, $errorMsgs errors found.";
	if ($copied > 0) {
		print "\n      ".$Sent." MB sent.  Total size is ".$Total." MB.\n";
		}
	else {
		print "\n";
		}
	if ($errorMsgs > 0) {
#		LogRoutines::LogErrorCounts($Candidates[$i][$posErrMsgsFile]);
		}
	print "  See messages in: ".$Candidates[$i][$posLogFile]."\n\n";	
  }

print "End Step $step_no: $BackupSteps incremental backup processes attempted.\n\n";

#-----------------------------------------------------

print "Daily backup process completed in $step_no steps at: ".LogRoutines::ConvTime(time)."\n";
exit $exitValue;  # Use whatever final setting of success/failure

#----------------------------------------------------------------
# Subroutines/Functions
#----------------------------------------------------------------
# Do RSYNC command
sub RsyncBackup 
{
	$RSYNC_cmd = "rsync -aqhi --delete --log-file='$_[2]' --filter='merge /home/dave/backups-filter.txt' $_[0] $_[1]";
	if (system ($RSYNC_cmd)==0) {
		print "    Backup successful on ".LogRoutines::ConvTime(time)." - ";
		$exitValue = 0;
		}
		else {
		print "  **Backup FAILED on ".LogRoutines::ConvTime(time)."!\n\n";
		$exitValue = 1; #Set overall indicator to 'failure'
		}

	my ($filesCopied,$filesDeleted,$errorMsgs,$MBSent,$MBTotal) = LogRoutines::LogAnalysis($_[2],$_[3],"v");

	return ($filesCopied, $filesDeleted, $errorMsgs, $MBSent, $MBTotal);
}


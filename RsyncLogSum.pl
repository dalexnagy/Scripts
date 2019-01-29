#! /usr/bin/perl
#
# RsyncLogSum.pl - Summarize results of Rsync by reading the log.
#
#------------------ CHANGE LOG -------------------------------------------------
# 11/27/2018	New 
# 11/29/2018	Commented some print statements, removed double newlines
# 
#
#-------------------------------------------------------------------------------
use strict;
use lib "/home/dave/Perl/Backups";
use LogRoutines;

# Get host name
use Sys::Hostname;
my $host = hostname;

# Get log file name from arguments (full Dir & Name)
my $LogFile = $ARGV[0];
# Create a log of errors found in log
(my $LogErrors = $LogFile) =~ s/.log/-Errors.log/;

#--------------------- MISC VARIABLES ------------------------------------------
my $exitValue = 0;  #Initially set to 'successful'
#--------------------- END OF VARIABLES --------------------

# Preamble
#print "\nReview Rsync Log File process started on system '$host' on ".LogRoutines::ConvTime(time)."\n";
#print "   via script '$0' (last updated on ".LogRoutines::ConvTime((stat($0))[9]).")\n\n";

my ($filesCopied,$filesDeleted,$errorMsgs,$MBSent,$MBTotal) = LogRoutines::LogAnalysis($LogFile,$LogErrors,"v");

print "Results:  $filesCopied files copied, $filesDeleted deleted, $errorMsgs errors found.";
if ($filesCopied > 0) {
	print "\n      ".$MBSent." MB sent.  Total size is ".$MBTotal." MB.\n";
	}
else {
	print "\n";
	}
if ($errorMsgs > 0) {
	print "See error messages in: ".$LogErrors."\n";	
  }

print "See all log messages in: ".$LogFile."\n\n";	

#print "Review Rsync Log File process completed at: ".LogRoutines::ConvTime(time)."\n\n";
exit $exitValue;  # Use whatever final setting of success/failure


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use Win32::Process::Perf;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

#!c:/perl/bin/perl -w
use Win32::Process::Perf;
use strict;

my $PERF = Win32::Process::Perf->new("RP", "UEDIT32");
if(!$PERF)
{
	die;
}

my $anz = $PERF->GetNumberofCounterNames();
print "$anz Counters available\n";
my %counternames = $PERF->GetCounterNames();

print "Avilable Counternames:\n";
foreach (1 .. $anz)
{
	print $counternames{$_} . "\n";
}
print "\n";

my $status = $PERF->PAddCounter();
if($status == 0) {
	my $error = $PERF->GetErrorText();
	print $error . "\n\n";
	exit;
}

print "Values...\n";
while(1)
{
	$status = $PERF->PCollectData();
	if($status == 0) {
		my $error = $PERF->GetErrorText();
		print "ERROR: " . $error . "\n";
		exit;
	}
	my %val = $PERF->PGetCounterValues($status);
	foreach  (1..$anz+1)
	{
		if(!$val{1}) { exit; }
		my $key = $counternames{$_};
		print "$key=" . $val{$_} . "\n";
	}
	sleep(1);
	print "\n";
}
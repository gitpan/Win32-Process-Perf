#!D:/perl/bin/perl -w
package Win32::Process::Perf;

use 5.006;
use strict;
use warnings;
use Carp;
use Win32::Locale;
use File::Basename;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = '0.02';

bootstrap Win32::Process::Perf $VERSION;

##########################
# Constructor
##########################
sub new
{
	my $class = shift;
	my $self = {};
	unless(scalar(@_) == 2)
	{
		croak("You must specify a machine to connect to and a process to monitor");
		return(undef);
	}
	$self->{'machine'}=shift;		# the PC name 
	$self->{'processname'}=shift;	# The name of the process which want to capture
	$self->{'logfile'}=undef;		# where the process informations are written
	$self->{'process'}="Prozess";	# used internal
	$self->{'counternames'}={},		# get availabel Counternames from File
	$self->{'counterhandels'}=[],
	$self->{'zaehler'}=	0,
	$self->{'HQUERY'}=	undef,
	$self->{'COUNTERS'}=undef,
	$self->{'useprocesstimes'}=0,
	$self->{'isError'}=0,
	$self->{'ERRORMSG'}=undef;
	$self->{'PERFMON'} = undef;
	bless $self, $class;

# now we have to load the language independend file which stores the Process Counters
	$self->LoadLanguageFile();
	my $res = connect_to_box($self->{'machine'}, $self->{'ERRORMSG'});
	if($res == 0)
	{
		$self->{'HQUERY'} = open_query();
		return $self;
	}
	else
	{
		print "Failed to connect to $self->{'machine'}! [$self->{'ERRORMSG'}]\n";
		return undef;
	}
}


sub PAddCounter
{
	my $self=shift;
	my $ObjectName = $self->{'process'};
	my $n_counters = $self->{'numberofcounters'};
	$self->{'isError'} = 0;
	if($self->{zaehler} >= $self->{'numberofcounters'}) { 
		$self->{'isError'} = 1;
		$self->{'ERRORMSG'} = "All counters allready added";
		return 0;
	}
	 
	my $query = $self->{'HQUERY'};
	foreach (1..$n_counters) {
		my $CounterName = $self->{'counternames'}->{$_};
		my $NewCounter = add_counter($self->{'process'},$self->{'processname'}, $CounterName, $self->{'HQUERY'}, $self->{'ERRORMSG'});
		if($self->{'ERRORMSG'}) { $self->{'isError'} = 1; }
		if($NewCounter == -1) { 
			$self->{'ERRORMSG'} .= " Counter ($ObjectName, $CounterName) not added";
			return 0;
		}
		$self->{'COUNTERS'}->{$_} = $NewCounter;
		
	}
	$self->{zaehler} = $n_counters;
	return 1;
}

sub PGetCounterValues
{
	my $self=shift;
	my $count = $self->{zaehler};
	my %h = ();
	my $c = 0;
	my $cputime=0;
	$self->{'isError'} = 0;
	
	foreach  (1 .. $count) {
		$c=$_;
		my $retval = collect_counter_value($self->{'HQUERY'}, $self->{'COUNTERS'}->{$c},$self->{'ERRORMSG'});
		if($retval == -1) {
			return;
		}
		if($c == 1)
		{
			$cputime = CPU_Time($retval,$self->{'ERRORMSG'});
		}
		$h{$c} = $retval;
	}
	$c++;
	$h{$c} = $cputime;
	return %h;
}

sub UseProcessTimes
{
	my $self=shift;
	$self->{'useprocesstimes'} =1;
	
}

sub SetOutputFormat
{
	my $self=shift;
	my $s_format = shift;
	
}



sub GetErrorText
{
	my $self=shift;
	return $self->{'ERRORMSG'};
}

sub GetNumberofCounterNames
{
	my $self=shift;
	return 	$self->{'numberofcounters'};
}
sub GetCounterNames
{
	my $self=shift;
	my %h = ();
	my $c;
	foreach (1 .. $self->{'numberofcounters'})
	{
		$c=$_;
		$h{$c} = $self->{'counternames'}->{$c};
	}
	$c++;
	$h{$c} = "CPU Time";
	return %h;
}

#################################
# 
# internal functions
# 

############################
#
# collect the data
#
sub PCollectData
{
	my $self=shift;
	$self->{'isError'} = 0;

	# Populate the counters associated witht he query object
	my $res = collect_data($self->{'HQUERY'}, $self->{'ERRORMSG'});
	
	if($res == -1)
	{
		$self->{'isError'} = 1;
	    return(0);

	}
	else
	{
	    return(1);
	}
}



sub LoadLanguageFile
{
	my $self=shift;
	# Get the language of the OS
	$self->{isError} = 0;
	$self->SetLanguage();
	$self->SetCounterNames();
	if($self->{isError} == 1) { return; }
	return 1;
	
}


sub SetLanguage
{
	my $self=shift;
	$self->{'language'} = Win32::Locale::get_language();
	
}

sub SetCounterNames
{
	my $self=shift;
	$self->{'isError'} = 0;
	my $path = dirname($INC{"Win32/Process/Perf.pm"});
	my $languagefile = $path . "/Perf/" . $self->{'language'} . ".dat";
	if(open(FH, $languagefile))	# reading language file 
	{
		my @list = <FH>;
		chomp(@list);
		close FH;
		$self->{'process'} = $list[0];
# set available counters
		my $count = 1;
		foreach (1..$#list)
		{
			my $line = $list[$_];
			$line =~ s/^\s*(.*?)\s*$/$1/;		# remove spaces from end and beginn of the line
			$self->{'counternames'}->{$count} = $line;
			$count++;
		}
		$count--;
		$self->{'numberofcounters'} = $count;
	} else { 
		$self->{'isError'} = 1; 
		$self->{'ERRORMSG'} = "Language " . $self->{'language'} . " not supported!";
		return 0;
	}
	return 1; 
}


sub PrintError
{
	my $self=shift;
	my $error=shift;
	print $error . "\n";
}

sub DESTROY { 
	my $self = shift;
	
	# If we have a query object, make sure we free it off
	if(defined($self->{'HQUERY'}))
	{
		CleanUp($self->{'HQUERY'});
		$self->{'HQUERY'} = undef;
	}
}

1;


__END__


=head1 NAME

Win32::Process::Perf Shows Performance counter for a process

=head1 VERSION
  
This document describes version 0.01 of Win32::Process::Perf, released
September 12, 2004.

=head1 SYNOPSIS
  
  use Win32::Process::Perf;
  my $PERF = Win32::Process::Perf->new(<computer name>, <process name>);
  # e.g. my $PERF = Win32::Process::Perf->new("MyPC", "explorer");
  # check if success:
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
  my $status = $PERF->PAddCounter();	# add all available counters to the query
  if($status == 0) {
	  my $error = $PERF->GetErrorText();
	  print $error . "\n";
	  exit;
  }
  while(1)
  {
	  $status = $PERF->PCollectData();
	  if($status == 0) {
		  my $error = $PERF->GetErrorText();
		  print $error . "\n";
		  exit;
	  }
	  my %val = $PERF->PGetCounterValues($status);
	  foreach  (1..$anz)
	  {
           if(!$val{$_}) { exit; }
		   my $key = $counternames{$_};
		   print "$key=" . $val{$_} . "\n";
	  }
	  sleep(1);
	  print "\n";
  }
  

=head1 ABSTRACT

The C<Win32::Process::Perf> provides an interface to the performance data of a specific running process.
It uses the PDH library.

=head1 DESCRIPTION

  The module provide an Interface to the performance data of a specific running process.
  It uses the PDH library.
  The modul uses Win32::Locale to get the language of the operating system. To add the support
  for your language please look in the site/lib/Win32/Process/Perf directory. There are samples
  for the counter definition. The counter data files have to be only in the directory 
  site/lib/Win32/Process/Perf.
  
  NOTE: The first line have to be the name for process in YOUR language. e.g. in german is it
  Prozess.
  The second line have to be the for the process ID in your language.
  At this time I have only support for Windows with en-us, de-at, de-ch. Maybe someone can 
  provide me with data files for his language.
  
  Sample for en-us (english US):
  Process
  ID Process
  
  Sample for de-at (german Austria,Germany):
  Prozess
  Prozesskennung
  
  Sample for spain: 
  (please provide me with one)

=head1 FUNCTIONS

=head2 NOTE

All funcitons return a non zero value if successful, and zero is they fail, excpet GetCounterValue()
which will return -1 if it fails.

=over 4

=item new($ServerName,$ProcessName)

The constructor. The required parameters are the PC name and the process which has to be captured.
Please check if the initialising of the module was successfull.

=item $PERF->GetErrorText()

Returns the error message from the last failed function call.

	my $err = $PERF->GetErrorText();

=item $PERF->PAddCounter()

This function add all process counters to the query.

    my $err = $PERF->PAddCounter();

The return code is 0 on failur.


=item $PERF->PCollectData()

PCollectData() collects the current raw data value for all counters in the specified query

   my $err $PERF->PCollectData();
	
On failur the return code is 0. 

=item $PERF->PGetCounterValues();

This function retrives the data of all added counters.   

   my %val = $PERF->PGetCounterValues();
	
To check if the process ended check if the value of the hash exist.
The last value of %val is the CPU time in seconds of the process.
Please take a look in test.pl

=back

=head1 PREREQUISITE

Perl Modules: L<File::Basename> <Win32::Locale>
Win32 dll's pdh.dll

=head1 TODO

1) Better handling of the conter names provided in the *.dat files.

=head1 AUTHOR

Reinhard Pagitsch <rpirpag@gmx.at>


=head1 SPECIAL THANKS

I want to give Glen Small my special thank, because without his module Win32::PerfMon the implementation
would taken much longer. 

=head1 SEE ALSO

L<Win32::PerfMon> L<perl>

=cut

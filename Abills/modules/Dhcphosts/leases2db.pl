#!/usr/bin/perl -w 
#

use vars  qw(%conf $db $DATE $time $var_dir);
use strict;

my $vesion = 0.1;

use FindBin '$Bin';
require $Bin . '/config.pl';
unshift(@INC, $Bin . '/../', $Bin . "/../Abills/$conf{dbtype}");
require Abills::Base;
Abills::Base->import();
my $begin_time = check_time();

require Abills::SQL;
my $sql = Abills::SQL->connect($conf{dbtype}, $conf{dbhost}, $conf{dbname}, $conf{dbuser}, $conf{dbpasswd});
my $db  = $sql->{db};

require Dhcphosts;
Dhcphosts->import();
my $Dhcphosts = Dhcphosts->new($db, undef, \%conf);


my $ARGV = parse_arguments(\@ARGV);

my $LEASES      = $ARGV->{LEASES} || $conf{DHCPHOSTS_LEASES} || "/var/db/dhcpd/dhcpd.leases";
my $UPDATE_TIME = $ARGV->{UPDATE_TIME} || 30;    # In Seconds
my $AUTO_VERIFY = 0;    
my $debug       = $ARGV->{DEBUG} || 0;

my $oldstat     = 0;
my $check_count = 0;
my $NAS_ID      = $ARGV->{NAS_ID} || 0;
my %state_hash  = ('unknown'   => 0,
                   'free'      => 1,
                   'active'    => 2,
                   'abandoned' => 3
                   );

my $log_dir = $var_dir.'/log';

if (defined($ARGV->{stop})) {
	stop($log_dir."/leases2db.pid");
	exit;
}


if(make_pid($log_dir."/leases2db.pid") == 1) {
  print "Already running!\n";
  exit;
}


$Dhcphosts->{debug}=1 if ($debug > 6);

if(defined($ARGV->{'-h'})){
	usage();
	exit;
}

print "Start...\n";
if(defined($ARGV->{'-d'})){
  print "leases2db.pl Daemonize..."; 
  daemonize();
 }


while(1){
	if(changed($LEASES)){
		my $list = pase($LEASES);
		do_stuff($list);
	}

	sleep $UPDATE_TIME;
}

#**********************************************************
# Check file change
#**********************************************************
sub changed {
	my ($file)  = @_;

if (! -f $LEASES) {
  print "Can't find leases file '$LEASES'.\n";

  exit;  
}
	my $custat = (stat($file))[9];
	
	if($AUTO_VERIFY){
		$check_count++;
	}

	if($oldstat != $custat || (($check_count == $AUTO_VERIFY) && $AUTO_VERIFY)){
		$oldstat = $custat;
		$check_count = 0;

		print "Timestamp change o AUTO_VERIFY tiggeed...\n" if ($debug > 0);
		return 1;
	}
	else{
		return 0;
	}
}



#**********************************************************
#
#**********************************************************
sub daemonize{
        chdir '/';
        umask 0;
        open STDIN, '/dev/null';
        open STDOUT, '/dev/null';
        open STDERR, '/dev/null';

        if(fork()){
                exit;
        }
        else{
                #setsid;
                return;
        }
}


#**********************************************************
#
#**********************************************************
sub pase {
   my ($logfile) = @_;
   my ( %list, $ip );

   print "Begin parse '$logfile'\n" if ($debug > 2);

   open (FILE, $logfile) || print "Can't read file '$logfile' $!\n";
   
   my $state = '';
   while (<FILE>) {
      next if /^#|^$/;

      if (/^lease (\d+\.\d+\.\d+\.\d+)/) {
         $ip = $1; 
         $list{$ip}{IP}=$ip;
       }
      # $list{$ip}{state} ne 'active' &&
      elsif ( /^\s*binding state ([a-zA-Z]{4,6});/) {
      	$state = $1;
      	$list{$ip}{STATE}=$state_hash{$state} if ($state eq 'active');
       }
      elsif (/^\s*client-hostname "(.*)";/) {
     	  $list{$ip}{'HOSTNAME'}=$1;
       }
      elsif (/^\s*hardware ethernet (.*);/) {
        $list{$ip}{HARDWARE}=$1;
       }


      /^\s*stats \d (\d{4})\/(\d{1,2})\/(\d{1,2}) (\d{1,2}):(\d{1,2}):(\d{1,2});/ && (  $list{$ip}{STARTS}="$1-$2-$3 $4:$5:$6" );
      /^\s*next binding state (.*);/ && (  $list{$ip}{NEXT_STATE}=$state_hash{$1} );
      /^\s*ends \d (\d{4})\/(\d{1,2})\/(\d{1,2}) (\d{1,2}):(\d{1,2}):(\d{1,2});/   && (  $list{$ip}{ENDS}="$1-$2-$3 $4:$5:$6" );
      /^\s*(abandoned).*/   && (    $list{$ip}{abandoned}=$1 );
      /^\s*option agent.circuit-id ([a-f0-9:]+);/ && (   $list{$ip}{CIRCUIT_ID}=$1 );
      /^\s*option agent.remote-id ([a-f0-9:]+);/ &&  (   $list{$ip}{REMOTE_ID}=$1  );
   }

   close FILE;

   return \%list;
}

#**********************************************************
#
#**********************************************************
sub do_stuff {
  my ($list) = @_;

  $Dhcphosts->leases_clear();

  my $i = 0;
	while(my ($ip, $hash) = each( %$list )) {
		$i++;
		if ($debug > 1) {
		  print "$ip \n" ;
		  while(my($k, $v) = each %{ $hash }) {
			  print "  $k, $v\n" if ($debug > 1);
		   }
		 }
    $Dhcphosts->leases_update({ %$hash, NAS_ID => $NAS_ID });
	}

  print "Updated: $i leases\n" if ($debug > 0);
}



#**********************************************************
#
#**********************************************************
sub usage{
	print <<EOF;
dhcp2ldapd v$vesion: Dynamic DNS Updates fo the Bind9 LDAP backend

Usage:
	dhcp2db [-d | -h | ...]

-d              uns dhcp2db in daemon mode
-h              displays this help message
LEASES=...      lease files
UPDATE_TIME=... Update peiod (Default: 30)
DEBUG=...       Debug mode 1-5
NAS_ID=         NAS ID (Default: 0)

Please edit the config vaiables befoe unning!

EOF
}


#**********************************************************
# Stop
#**********************************************************
sub stop {
  my ($pid_file, $attr) = @_;


  my $a = `kill \`cat $pid_file\``;
}

#**********************************************************
# Check running program
#**********************************************************
sub make_pid {
  my ($pid_file, $attr) = @_;
  
  if ($attr && $attr eq 'clean') {
  	unlink($pid_file);
  	return 0;
   }
  
  if (-f $pid_file) {
  	open(PIDFILE, "$pid_file") || die "Can't open pid file '$pid_file' $!\n";
  	  my @pids = <PIDFILE>;
  	close(PIDFILE);
    
    my $pid = $pids[0];
    if(verify($pid)) {
     	print "Proccess running PID: $pid\n";
   	  return 1;
     }
   }
  
  my $traffic2sql_pid = $$;  
	open(PIDFILE, ">$pid_file") || die "Can't open pid file '$pid_file' $!\n";
	  print PIDFILE $traffic2sql_pid;
	close(PIDFILE);    
  
  return 0;
}



#**********************************************************
# Check running program
#**********************************************************
sub verify {
    my ($pid) = @_;

    return 0 if ($pid eq '');

    my $me = $$;  # = $self->{verify};

    my @ps = split m|$/|, qx/ps -fp $pid/
           || die "ps utility not available: $!";
    s/^\s+// for @ps;   # leading spaces confuse us

    no warnings;    # hate that deprecated @_ thing
    my $n = split(/\s+/, $ps[0]);
    @ps = split /\s+/, $ps[1], $n;

    return ($ps[0]) ? 1 : 0;
}

#############################################################################
#This pogam is fee softwae; you can edistibute it and/o modify
#it unde the tems of the GNU Geneal Public License as published by
#the Fee Softwae Foundation; eithe vesion 2 of the License, o
#(at you option) any late vesion.
#
#This pogam is distibuted in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied waanty of
#MERCHANTABILITY o FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU Geneal Public License fo moe details.
#
#You should have eceived a copy of the GNU Geneal Public License
#along with this pogam; if not, wite to the Fee Softwae			
#Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  
#############################################################################

package Auth;
# Auth functions
#

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
);

use Exporter;
$VERSION = 2.00;
@ISA = ('Exporter');
@EXPORT = qw(
  &check_chap
  &check_company_account
  &check_bill_account
);

@EXPORT_OK = ();
%EXPORT_TAGS = ();

# User name expration
#my $usernameregexp = "^[a-z0-9_][a-z0-9_-]*\$"; # configurable;
use main;
@ISA  = ("main");
my $db;
my $CONF;

#**********************************************************
# Init 
#**********************************************************
sub new {
  my $class = shift;
  ($db, $CONF) = @_;
  my $self = { };
  bless($self, $class);
  #$self->{debug}=1;

  if (! defined($CONF->{KBYTE_SIZE})) {
  	 $CONF->{KBYTE_SIZE}=1024;
  	}

  return $self;
}

#**********************************************************
# Dialup & VPN auth
#**********************************************************
sub dv_auth {
  my $self = shift;
  my ($RAD, $NAS, $attr) = @_;
	
	
  my ($ret, $RAD_PAIRS) = $self->authentication($RAD, $NAS, $attr);
  if ($ret == 1) {
     return 1, $RAD_PAIRS;
  }

	
  $self->query($db, "select
  if (dv.logins=0, tp.logins, dv.logins) AS logins,
  if(dv.filter_id != '', dv.filter_id, tp.filter_id),
  if(dv.ip>0, INET_NTOA(dv.ip), 0),
  INET_NTOA(dv.netmask),
  dv.tp_id,
  dv.speed,
  dv.cid,
  tp.day_time_limit,
  tp.week_time_limit,
  tp.month_time_limit,
  UNIX_TIMESTAMP(DATE_FORMAT(DATE_ADD(curdate(), INTERVAL 1 MONTH), '%Y-%m-01')) - UNIX_TIMESTAMP(),

  day_traf_limit,
  week_traf_limit,
  month_traf_limit,
  tp.octets_direction,
  
  if (count(un.uid) + count(tp_nas.tp_id) = 0, 0,
    if (count(un.uid)>0, 1, 2)),

  UNIX_TIMESTAMP(),
  UNIX_TIMESTAMP(DATE_FORMAT(FROM_UNIXTIME(UNIX_TIMESTAMP()), '%Y-%m-%d')),
  DAYOFWEEK(FROM_UNIXTIME(UNIX_TIMESTAMP())),
  DAYOFYEAR(FROM_UNIXTIME(UNIX_TIMESTAMP())),
  dv.disable,
  if(tp.hourp + tp.day_fee + tp.month_fee=0 and (sum(tt.in_price + tt.out_price)=0 or sum(tt.in_price + tt.out_price)IS NULL), 0, 1),
  tp.max_session_duration,
  tp.payment_type,
  tp.credit_tresshold,
  tp.rad_pairs
     FROM dv_main dv, tarif_plans tp
     LEFT JOIN trafic_tarifs tt ON (tt.tp_id=dv.tp_id)
     LEFT JOIN users_nas un ON (un.uid = dv.uid)
     LEFT JOIN tp_nas ON (tp_nas.tp_id = tp.id)
     WHERE dv.tp_id=tp.id
        AND dv.uid='$self->{UID}'
     GROUP BY dv.uid;");


  if($self->{errno}) {
  	$RAD_PAIRS->{'Reply-Message'}='SQL error';
  	return 1, $RAD_PAIRS;
   }
  elsif ($self->{TOTAL} < 1) {
    $RAD_PAIRS->{'Reply-Message'}="Service not allow";
    return 1, $RAD_PAIRS;
   }

#  print $RAD_PAIRS->{'MS-CHAP-MPPE-Keys'};

  my $a_ref = $self->{list}->[0];

  ($self->{LOGINS}, 
     $self->{FILTER}, 
     $self->{IP}, 
     $self->{NETMASK}, 
     $self->{TP_ID}, 
     $self->{USER_SPEED}, 
     $self->{CID},
     $self->{DAY_TIME_LIMIT},  $self->{WEEK_TIME_LIMIT},   $self->{MONTH_TIME_LIMIT}, $self->{TIME_LIMIT},
     $self->{DAY_TRAF_LIMIT},  $self->{WEEK_TRAF_LIMIT},   $self->{MONTH_TRAF_LIMIT}, $self->{OCTETS_DIRECTION},
     $self->{NAS}, 
     $self->{SESSION_START}, 
     $self->{DAY_BEGIN}, 
     $self->{DAY_OF_WEEK}, 
     $self->{DAY_OF_YEAR},
     $self->{DISABLE},
     $self->{TP_PAYMENT},
     $self->{MAX_SESSION_DURATION},
     $self->{PAYMENT_TYPE},
     $self->{CREDIT_TRESSHOLD},
     $self->{TP_RAD_PAIRS}
    ) = @$a_ref;



#return 0, \%RAD_PAIRS;

#DIsable
if ($self->{DISABLE}) {
  $RAD_PAIRS->{'Reply-Message'}="Service Disable";
  return 1, $RAD_PAIRS;
}


##Check allow nas server
## $nas 1 - See user nas
##      2 - See tp nas
# if ($self->{NAS} > 0) {
#   my $sql;
#   if ($self->{NAS} == 1) {
#      $sql = "SELECT un.uid FROM users_nas un WHERE un.uid='$self->{UID}' and un.nas_id='$NAS->{NID}'";
#     }
#   else {
#      $sql = "SELECT nas_id FROM tp_nas WHERE tp_id='$self->{TP_ID}' and nas_id='$NAS->{NID}'";
#     }
#
#   $self->query($db, "$sql");
#   if ($self->{TOTAL} < 1) {
#     $RAD_PAIRS{'Reply-Message'}="You are not authorized to log in $NAS->{NID} ($RAD->{NAS_IP_ADDRESS})";
#     return 1, \%RAD_PAIRS;
#    }
#  }

#Check CID (MAC) 
if ($self->{CID} ne '') {
  my ($ret, $ERR_RAD_PAIRS) = $self->Auth_CID($RAD);
  return $ret, $ERR_RAD_PAIRS if ($ret == 1);
}



#Check  simultaneously logins if needs
if ($self->{LOGINS} > 0) {
  $self->query($db, "SELECT count(*) FROM calls WHERE user_name='$RAD->{USER_NAME}' and status <> 2;");
  
  my $a_ref = $self->{list}->[0];
  my($active_logins) = @$a_ref;
  if ($active_logins >= $self->{LOGINS}) {
    $RAD_PAIRS->{'Reply-Message'}="More then allow login ($self->{LOGINS}/$active_logins)";
    return 1, $RAD_PAIRS;
   }
}


my @time_limits = ();
my $remaining_time=0;
my $ATTR;

#Chack Company account if ACCOUNT_ID > 0
if ($self->{PAYMENT_TYPE} == 0) {
  $self->{DEPOSIT}=$self->{DEPOSIT}+$self->{CREDIT}-$self->{CREDIT_TRESSHOLD};

  #Check deposit
  if($self->{TP_PAYMENT} > 0 && $self->{DEPOSIT}  <= 0) {
    $RAD_PAIRS->{'Reply-Message'}="Negativ deposit '$self->{DEPOSIT}'. Rejected!";
    return 1, $RAD_PAIRS;
   }
  
  ($remaining_time, $ATTR) = $self->remaining_time($self->{TP_ID}, $self->{DEPOSIT}, 
                                      $self->{SESSION_START}, 
                                      $self->{DAY_BEGIN}, 
                                      $self->{DAY_OF_WEEK}, 
                                      $self->{DAY_OF_YEAR},
                                      { mainh_tarif => $self->{TIME_TARIF},
                                        time_limit  => $self->{TODAY_LIMIT}  } 
                                      );

}


if (defined($ATTR->{TT})) {
  $self->{TT_INTERVAL} = $ATTR->{TT};
}
else {
  $self->{TT_INTERVAL} = 0;
}

#check allow period and time out
 if ($remaining_time == -1) {
 	  $RAD_PAIRS->{'Reply-Message'}="Not Allow day";
    return 1, $RAD_PAIRS;
  }
 elsif ($remaining_time == -2) {
    $RAD_PAIRS->{'Reply-Message'}="Not Allow time";
    return 1, $RAD_PAIRS;
  }
 elsif($remaining_time > 0) {
    push (@time_limits, $remaining_time);
  }

#Periods Time and traf limits
# 0 - Total limit
# 1 - Day limit
# 2 - Week limit
# 3 - Month limit
my @traf_limits = ();
my $time_limit  = $self->{TIME_LIMIT}; 
my $traf_limit  = $attr->{MAX_SESSION_TRAFFIC};

push @time_limits, $self->{MAX_SESSION_DURATION} if ($self->{MAX_SESSION_DURATION} > 0);

my @periods = ('DAY', 'WEEK', 'MONTH');

foreach my $line (@periods) {
     if (($self->{$line . '_TIME_LIMIT'} > 0) || ($self->{$line . '_TRAF_LIMIT'} > 0)) {
        $self->query($db, "SELECT if(". $self->{$line . '_TIME_LIMIT'} ." > 0, ". $self->{$line . '_TIME_LIMIT'} ." - sum(duration), 0),
                                  if(". $self->{$line . '_TRAF_LIMIT'} ." > 0, ". $self->{$line . '_TRAF_LIMIT'} ." - sum(sent + recv) / 1024 / 1024, 0) 
            FROM log
            WHERE uid='$self->{UID}' and DATE_FORMAT(start, '%Y-%m-%d')=curdate()
            GROUP BY DATE_FORMAT(start, '%Y-%m-%d');");

        if ($self->{TOTAL} == 0) {
          push (@time_limits, $self->{$line . '_TIME_LIMIT'}) if ($self->{$line . '_TIME_LIMIT'} > 0);
          push (@traf_limits, $self->{$line . '_TRAF_LIMIT'}) if ($self->{$line . '_TRAF_LIMIT'} > 0);
         } 
        else {
        	$a_ref = $self->{list}->[0];
          my ($time_limit, $traf_limit) = @$a_ref;
          push (@time_limits, $time_limit) if ($self->{$line . '_TIME_LIMIT'} > 0);
          push (@traf_limits, $traf_limit) if ($self->{$line . '_TRAF_LIMIT'} > 0);
         }
       }
}


#set traffic limit
#push (@traf_limits, $prepaid_traff) if ($prepaid_traff > 0);

 for(my $i=0; $i<=$#traf_limits; $i++) {
 	 #print $traf_limits[$i]. "------\n";
   if ($traf_limit > $traf_limits[$i]) {
     $traf_limit = int($traf_limits[$i]);
    }
  }

 if($traf_limit < 0) {
   $RAD_PAIRS->{'Reply-Message'}="Rejected! Traffic limit utilized '$traf_limit Mb'";
   return 1, $RAD_PAIRS;
  }



#set time limit
 for(my $i=0; $i<=$#time_limits; $i++) {
   if ($time_limit > $time_limits[$i]) {
     $time_limit = $time_limits[$i];
    }
  }

 if ($time_limit > 0) {
   $RAD_PAIRS->{'Session-Timeout'} = "$time_limit";
  }
 elsif($time_limit < 0) {
   $RAD_PAIRS->{'Reply-Message'}="Rejected! Time limit utilized '$time_limit'";
   return 1, $RAD_PAIRS;
  }

# Return radius attr    
 if ($self->{IP} ne '0') {
   $RAD_PAIRS->{'Framed-IP-Address'} = "$self->{IP}";
  }
 else {
   my $ip = $self->get_ip($NAS->{NID}, "$RAD->{NAS_IP_ADDRESS}");
   if ($ip eq '-1') {
     $RAD_PAIRS->{'Reply-Message'}="Rejected! There is no free IPs in address pools ($NAS->{NID})";
     return 1, $RAD_PAIRS;
    }
   elsif($ip eq '0') {
     #$RAD_PAIRS->{'Reply-Message'}="$self->{errstr} ($NAS->{NID})";
     #return 1, $RAD_PAIRS;
    }
   else {
     $RAD_PAIRS->{'Framed-IP-Address'} = "$ip";
    }
  }

  $RAD_PAIRS->{'Framed-IP-Netmask'} = "$self->{NETMASK}" if(defined($RAD_PAIRS->{'Framed-IP-Address'}));
  $RAD_PAIRS->{'Filter-Id'} = "$self->{FILTER}" if (length($self->{FILTER}) > 0); 



####################################################################
# Vendor specific return
# ExPPP

if ($NAS->{NAS_TYPE} eq 'exppp') {
  #$traf_tarif 
  my $EX_PARAMS = $self->ex_traffic_params( { 
  	                                        traf_limit => $traf_limit, 
                                            deposit => $self->{DEPOSIT},
                                            MAX_SESSION_TRAFFIC => $attr->{MAX_SESSION_TRAFFIC} });

  #global Traffic
  if ($EX_PARAMS->{traf_limit} > 0) {
    $RAD_PAIRS->{'Exppp-Traffic-Limit'} = $EX_PARAMS->{traf_limit} * 1024 * 1024;
   }

  #Local traffic
  if ($EX_PARAMS->{traf_limit_lo} > 0) {
    $RAD_PAIRS->{'Exppp-LocalTraffic-Limit'} = $EX_PARAMS->{traf_limit_lo} * 1024 * 1024 ;
   }
       
  #Local ip tables
  if (defined($EX_PARAMS->{nets})) {
    $RAD_PAIRS->{'Exppp-Local-IP-Table'} = "\"$attr->{NETS_FILES_PATH}$self->{TT_INTERVAL}.nets\"";
   }

#Shaper for exppp
#  if ($self->{USER_SPEED} > 0) {
#    $RAD_PAIRS->{'Exppp-Traffic-Shape'} = int($self->{USER_SPEED});
#   }
#  else {
#    if ($EX_PARAMS->{speed}  > 0) {
#      $RAD_PAIRS->{'Exppp-Traffic-Shape'} = $EX_PARAMS->{speed};
#     }
#   }

=comments
        print "Exppp-Traffic-In-Limit = $trafic_inlimit,";
        print "Exppp-Traffic-Out-Limit = $trafic_outlimit,";
        print "Exppp-LocalTraffic-In-Limit = $trafic_lo_inlimit,";
        print "Exppp-LocalTraffic-Out-Limit = $trafic_lo_outlimit,";
=cut
 }
###########################################################
# MPD
elsif ($NAS->{NAS_TYPE} eq 'mpd') {
  my $EX_PARAMS = $self->ex_traffic_params({ 
  	                                        traf_limit => $traf_limit, 
                                            deposit => $self->{DEPOSIT},
                                            MAX_SESSION_TRAFFIC => $attr->{MAX_SESSION_TRAFFIC} });

  #global Traffic
  if ($EX_PARAMS->{traf_limit} > 0) {
    $RAD_PAIRS->{'Exppp-Traffic-Limit'} = $EX_PARAMS->{traf_limit} * 1024 * 1024;
   }
       
#MPD standart radius based Shaper
#  if ($uspeed > 0) {
#    $RAD_PAIRS{'mpd-rule'} = "\"1=pipe %p1 ip from any to any\"";
#    $RAD_PAIRS{'mpd-pipe'} = "\"1=bw ". $uspeed ."Kbyte/s\"";
#   }
#  else {
#    if ($v_speed > 0) {
#      $RAD_PAIRS{'Exppp-Traffic-Shape'} = $v_speed;
#      $RAD_PAIRS{'mpd-rule'} = "1=pipe %p1 ip from any to any";
#      $RAD_PAIRS{'mpd-pipe'} = "1=bw ". $v_speed ."Kbyte/s";
#     }
#   }
 }
###########################################################
# pppd + RADIUS plugin (Linux) http://samba.org/ppp/
elsif ($NAS->{NAS_TYPE} eq 'pppd') {
  my $EX_PARAMS = $self->ex_traffic_params( { 
  	                                        traf_limit => $traf_limit, 
                                            deposit => $self->{DEPOSIT},
                                            MAX_SESSION_TRAFFIC => $attr->{MAX_SESSION_TRAFFIC} });

  #global Traffic
  if ($EX_PARAMS->{traf_limit} > 0) {
    $RAD_PAIRS->{'Session-Octets-Limit'} = $EX_PARAMS->{traf_limit} * 1024 * 1024;
    $RAD_PAIRS->{'Octets-Direction'} = 0;
   }
 }

#Auto assing MAC in first connect
if( defined($CONF->{MAC_AUTO_ASSIGN}) && 
       $CONF->{MAC_AUTO_ASSIGN}==1 && 
       $self->{CID} eq '' && 
       (defined($RAD->{CALLING_STATION_ID}) && $RAD->{CALLING_STATION_ID} =~ /:/ && $RAD->{CALLING_STATION_ID} !~ /\// )
      ) {
#  print "ADD MAC___\n";
  $self->query($db, "UPDATE dv_main SET cid='$RAD->{CALLING_STATION_ID}'
     WHERE uid='$self->{UID}';", 'do');
}

  if ($self->{TP_RAD_PAIRS}) {
  	my @p = split(/,/, $self->{TP_RAD_PAIRS});
    foreach my $line (@p) {
    	my ($rk, $lk)=split(/=/, $line);
    	$RAD_PAIRS->{$rk}="$lk";
     }
  }
#OK
  return 0, $RAD_PAIRS, '';
}
	

#*********************************************************
# Auth_mac
# Mac auth function
#*********************************************************
sub Auth_CID {
  my $self = shift;
  my ($RAD, $attr) = @_;
  
  my $RAD_PAIRS;
  
  my @MAC_DIGITS_GET = ();

   if (($self->{CID} =~ /:/ || $self->{CID} =~ /-/)
       && $self->{CID} !~ /./) {

      #@MAC_DIGITS_GET=split(/:/, $self->{CID}) if($self->{CID} =~ /:/);
      @MAC_DIGITS_GET=split(/:|-/, $self->{CID});
      my @MAC_DIGITS_NEED=split(/:/, $RAD->{CALLING_STATION_ID});
      for(my $i=0; $i<=5; $i++) {
        if(hex($MAC_DIGITS_NEED[$i]) != hex($MAC_DIGITS_GET[$i])) {
          $RAD_PAIRS->{'Reply-Message'}="Wrong MAC '$RAD->{CALLING_STATION_ID}'";
          return 1, $RAD_PAIRS, "Wrong MAC '$RAD->{CALLING_STATION_ID}'";
         }
       }
    }
   # If like MPD CID
   # 192.168.101.2 / 00:0e:0c:4a:63:56 
   elsif($self->{CID} =~ /\//) {
     $RAD->{CALLING_STATION_ID} =~ s/ //g;
     my ($cid_ip, $cid_mac, $trash) = split(/\//, $RAD->{CALLING_STATION_ID}, 3);
     if ("$cid_ip/$cid_mac" ne $self->{CID}) {
       $RAD_PAIRS->{'Reply-Message'}="Wrong CID '$cid_ip/$cid_mac'";
       return 1, $RAD_PAIRS;
      }
    }
   elsif($self->{CID} ne $RAD->{CALLING_STATION_ID}) {
     $RAD_PAIRS->{'Reply-Message'}="Wrong CID '$RAD->{CALLING_STATION_ID}'";
     return 1, $RAD_PAIRS;
    }

}

#**********************************************************
# User authentication
# authentication($RAD_HASH_REF, $NAS_HASH_REF, $attr)
#
# return ($r, $RAD_PAIRS_REF);
#**********************************************************
sub authentication {
  my $self = shift;
  my ($RAD, $NAS, $attr) = @_;
  
 
  my $SECRETKEY = (defined($CONF->{secretkey})) ? $CONF->{secretkey} : '';
  my %RAD_PAIRS = ();
  
  $self->query($db, "select
  u.uid,
  DECODE(password, '$SECRETKEY'),
  UNIX_TIMESTAMP(),
  UNIX_TIMESTAMP(DATE_FORMAT(FROM_UNIXTIME(UNIX_TIMESTAMP()), '%Y-%m-%d')),
  DAYOFWEEK(FROM_UNIXTIME(UNIX_TIMESTAMP())),
  DAYOFYEAR(FROM_UNIXTIME(UNIX_TIMESTAMP())),
  u.company_id,
  u.disable,
  u.bill_id,
  u.credit
     FROM users u
     WHERE 
        u.id='$RAD->{USER_NAME}'
        AND (u.expire='0000-00-00' or u.expire > CURDATE())
        AND (u.activate='0000-00-00' or u.activate <= CURDATE())
       GROUP BY u.id;");


  if($self->{errno}) {
  	$RAD_PAIRS{'Reply-Message'}='SQL error';
  	return 1, \%RAD_PAIRS;
   }
  elsif ($self->{TOTAL} < 1) {
    $RAD_PAIRS{'Reply-Message'}="Login Not Exist";
    return 1, \%RAD_PAIRS;
   }

  my $a_ref = $self->{list}->[0];

  ($self->{UID}, 
     $self->{PASSWD}, 
     $self->{SESSION_START}, 
     $self->{DAY_BEGIN}, 
     $self->{DAY_OF_WEEK}, 
     $self->{DAY_OF_YEAR},
     $self->{COMPANY_ID},
     $self->{DISABLE},
     $self->{BILL_ID},
     $self->{CREDIT}
    ) = @$a_ref;



#return 0, \%RAD_PAIRS;


#Auth chap
if (defined($RAD->{CHAP_PASSWORD}) && defined($RAD->{CHAP_CHALLENGE})) {
  if (check_chap("$RAD->{CHAP_PASSWORD}", "$self->{PASSWD}", "$RAD->{CHAP_CHALLENGE}", 0) == 0) {
    $RAD_PAIRS{'Reply-Message'}="Wrong CHAP password '$self->{PASSWD}'";
    return 1, \%RAD_PAIRS;
   }      	 	
 }
#Auth MS-CHAP v1,v2
elsif(defined($RAD->{MS_CHAP_CHALLENGE})) {
  # Its an MS-CHAP V2 request
  # See draft-ietf-radius-ms-vsa-01.txt,
  # draft-ietf-pppext-mschap-v2-00.txt, RFC 2548, RFC3079
  $RAD->{MS_CHAP_CHALLENGE} =~ s/^0x//;
  my $challenge = pack("H*", $RAD->{MS_CHAP_CHALLENGE});
  my ($usersessionkey, $lanmansessionkey, $ms_chap2_success);

  if (defined($RAD->{MS_CHAP2_RESPONSE})) {
     $RAD->{MS_CHAP2_RESPONSE} =~ s/^0x//; 
     my $rad_response = pack("H*", $RAD->{MS_CHAP2_RESPONSE});
     my ($ident, $flags, $peerchallenge, $reserved, $response) = unpack('C C a16 a8 a24', $rad_response);

     if (check_mschapv2("$RAD->{USER_NAME}", $self->{PASSWD}, $challenge, $peerchallenge, $response, $ident,
 	     \$usersessionkey, \$lanmansessionkey, \$ms_chap2_success) == 0) {
         $RAD_PAIRS{'MS-CHAP-Error'}="\"Wrong MS-CHAP2 password\"";
         $RAD_PAIRS{'Reply-Message'}=$RAD_PAIRS{'MS-CHAP-Error'};
         return 1, \%RAD_PAIRS;
	    }

     $RAD_PAIRS{'MS-CHAP2-SUCCESS'} = '0x' . bin2hex($ms_chap2_success);
     my ($send, $recv) = Radius::MSCHAP::mppeGetKeys($usersessionkey, $response, 16);


# MPPE Sent/Recv Key Not realizet now.
#        print "\n--\n'$usersessionkey'\n'$response'\n'$send'\n'$recv'\n--\n";
#        $RAD_PAIRS{'MS-MPPE-Send-Key'}="0x".bin2hex( substr(encode_mppe_key($send, $radsecret, $challenge), 0, 16));
#	       $RAD_PAIRS{'MS-MPPE-Recv-Key'}="0x".bin2hex( substr(encode_mppe_key($recv, $radsecret, $challenge), 0, 16));

#        my $radsecret = 'test';
#         $RAD_PAIRS{'MS-MPPE-Send-Key'}="0x".bin2hex(encode_mppe_key($send, $radsecret, $challenge));
#	       $RAD_PAIRS{'MS-MPPE-Recv-Key'}="0x".bin2hex(encode_mppe_key($recv, $radsecret, $challenge));

#        $RAD_PAIRS{'MS-MPPE-Send-Key'}='0x4f835a2babe6f2600a731fd89ef25a38';
#	       $RAD_PAIRS{'MS-MPPE-Recv-Key'}='0x27ac8322247937ad3010161f1d5bbe5c';
	       
        }
       else {
         my $message;
  
         if (check_mschap("$self->{PASSWD}", "$RAD->{MS_CHAP_CHALLENGE}", "$RAD->{MS_CHAP_RESPONSE}", 
	           \$usersessionkey, \$lanmansessionkey, \$message) == 0) {
           $message = "Wrong MS-CHAP password";
           $RAD_PAIRS{'MS-CHAP-Error'}="\"$message\"";
           $RAD_PAIRS{'Reply-Message'}=$message;
           return 1, \%RAD_PAIRS;
          }
        }

       $RAD_PAIRS{'MS-CHAP-MPPE-Keys'} = '0x' . unpack("H*", (pack('a8 a16', $lanmansessionkey, 
														$usersessionkey))) . "0000000000000000";

       # 1      Encryption-Allowed 
       # 2      Encryption-Required 
       $RAD_PAIRS{'MS-MPPE-Encryption-Policy'} = '0x00000001';
       $RAD_PAIRS{'MS-MPPE-Encryption-Types'} = '0x00000006';      
    


 }
#End MSchap auth
elsif($NAS->{NAS_AUTH_TYPE} == 1) {
  if (check_systemauth("$RAD->{USER_NAME}", "$RAD->{USER_PASSWORD}") == 0) { 
    $RAD_PAIRS{'Reply-Message'}="Wrong password '$RAD->{USER_PASSWORD}' $NAS->{NAS_AUTH_TYPE}";
    return 1, \%RAD_PAIRS;
   }
 } 
#If don't athorize any above methods auth PAP password
else {
  if(defined($RAD->{USER_PASSWORD}) && $self->{PASSWD} ne $RAD->{USER_PASSWORD}) {
    $RAD_PAIRS{'Reply-Message'}="Wrong password '$RAD->{USER_PASSWORD}'";
    return 1, \%RAD_PAIRS;
   }
}

my @time_limits = ();
my $remaining_time=0;
my $ATTR;

#Chack Company account if ACCOUNT_ID > 0
$self->check_company_account() if ($self->{COMPANY_ID} > 0);
if($self->{errno}) {
  $RAD_PAIRS{'Reply-Message'}=$self->{errstr};
  return 1, \%RAD_PAIRS;
 }

#DIsable
if ($self->{DISABLE}) {
  $RAD_PAIRS{'Reply-Message'}="Account Disable";
  return 1, \%RAD_PAIRS;
}


$self->check_bill_account();
if($self->{errno}) {
  $RAD_PAIRS{'Reply-Message'}=$self->{errstr};
  return 1, \%RAD_PAIRS;
 }


  return 0, \%RAD_PAIRS, '';
}


#*******************************************************************
#Chack Company account if ACCOUNT_ID > 0
# check_company_account()
#*******************************************************************
sub check_bill_account() {
  my $self = shift;

#get sum from bill account
   $self->query($db, "SELECT deposit FROM bills WHERE id='$self->{BILL_ID}';");
   if($self->{errno}) {
  	  return $self;
     }
    elsif ($self->{TOTAL} < 1) {
      $self->{errstr}="Bill account Not Exist";
      return $self;
     }

   ($self->{DEPOSIT}) = $self->{list}->[0]->[0];

  return $self;
}
#*******************************************************************
#Chack Company account if ACCOUNT_ID > 0
# check_company_account()
#*******************************************************************
sub check_company_account () {
	my $self = shift;

  $self->query($db, "SELECT bill_id, disable FROM companies WHERE id='$self->{COMPANY_ID}';");

 
  if($self->{errno}) {
 	  return $self;
   }
  elsif ($self->{TOTAL} < 1) {
    $self->{errstr}="Company ID '$self->{COMPANY_ID}' Not Exist";

    $self->{errno}=1;
    return $self;
   }

  my $a_ref = $self->{list}->[0];

  ($self->{BILL_ID},
   $self->{DISABLE},
    ) = @$a_ref;

  return $self;
}


#*******************************************************************
# Extended traffic parameters
# ex_params($tp_id)
#*******************************************************************
sub ex_traffic_params {
 my ($self, $attr) = @_;	

 my $traf_limit = $attr->{traf_limit};
 my $deposit = (defined($attr->{deposit})) ? $attr->{deposit} : 0;

 my %EX_PARAMS = ();
 $EX_PARAMS{speed}=0;
 $EX_PARAMS{traf_limit}=0;
 $EX_PARAMS{traf_limit_lo}=0;

 my %prepaids = ();
 my %speeds = ();
 my %in_prices = ();
 my %out_prices = ();
 my %trafic_limits = ();
 
 
 #get traffic limits
# if ($traf_tarif > 0) {
   my $nets = 0;
#$self->{debug}=1;
   $self->query($db, "SELECT id, in_price, out_price, prepaid, in_speed, out_speed, LENGTH(nets) FROM trafic_tarifs
             WHERE interval_id='$self->{TT_INTERVAL}';");

   if ($self->{TOTAL} < 1) {
     return \%EX_PARAMS;	
    }
   elsif($self->{errno}) {
   	 return \%EX_PARAMS;
    }

   my $list = $self->{list};
   foreach my $line (@$list) {
     $prepaids{$line->[0]}=$line->[3];
     $in_prices{$line->[0]}=$line->[1];
     $out_prices{$line->[0]}=$line->[2];
     $speeds{$line->[0]}{IN}=$line->[4];
     $speeds{$line->[0]}{OUT}=$line->[5];
     $nets+=$line->[6];
    }

   $EX_PARAMS{nets}=$nets if ($nets > 20);
   #$EX_PARAMS{speed}=int($speeds{0}) if (defined($speeds{0}));

#  }
# else {
#   return %EX_PARAMS;	
#  }


if ((defined($prepaids{0}) || defined($prepaids{0})) && ($prepaids{0}+$prepaids{1}>0)) {
  $self->query($db, "SELECT sum(sent+recv) / 1024 / 1024, sum(sent2+recv2) / 1024 / 1024 FROM log 
     WHERE uid='$self->{UID}' and DATE_FORMAT(start, '%Y-%m')=DATE_FORMAT(curdate(), '%Y-%m')
     GROUP BY DATE_FORMAT(start, '%Y-%m');");

  if ($self->{TOTAL} == 0) {
    $trafic_limits{0}=$prepaids{0};
    $trafic_limits{1}=$prepaids{1};
   }
  else {
    my $used = $self->{list}->[0];

    if ($used->[0] < $prepaids{0}) {
      $trafic_limits{0}=$prepaids{0} - $used->[0];
     }
    elsif($in_prices{0} + $out_prices{0} > 0) {
      $trafic_limits{0} = ($deposit / (($in_prices{0} + $out_prices{0}) / 2));
     }

    if ($used->[1]  < $prepaids{1}) {
      $trafic_limits{1}=$prepaids{1} - $used->[1];
     }
    elsif($in_prices{1} + $out_prices{1} > 0) {
      $trafic_limits{1} = ($deposit / (($in_prices{1} + $out_prices{1}) / 2));
     }
   }
   
 }
else {
  if ($in_prices{0}+$out_prices{0} > 0) {
    $trafic_limits{0} = ($deposit / (($in_prices{0} + $out_prices{0}) / 2));
   }

  if ($in_prices{1}+$out_prices{1} > 0) {
    $trafic_limits{1} = ($deposit / (($in_prices{1} + $out_prices{1}) / 2));
   }
  else {
    $trafic_limits{1} = 0;
   }
}

#Traffic limit


my $trafic_limit = 0;
if ($trafic_limits{0} > 0 || $traf_limit > 0) {
  if($trafic_limits{0} > $traf_limit && $traf_limit > 0) {
    $trafic_limit = $traf_limit;
   }
  elsif($trafic_limits{0} > 0) {
    #$trafic_limit = $trafic_limit * 1024 * 1024;
    #2Gb - (2048 * 1024 * 1024 ) - global traffic session limit
    $trafic_limit = ($trafic_limits{0} > $attr->{MAX_SESSION_TRAFFIC}) ? $attr->{MAX_SESSION_TRAFFIC} :  $trafic_limits{0};
   }
  else {
  	$trafic_limit = $traf_limit;
   }

  $EX_PARAMS{traf_limit} = ($trafic_limit < 1 && $trafic_limit > 0) ? 1 : int($trafic_limit);
}

#Local Traffic limit
if ($trafic_limits{1} > 0) {
  #10Gb - (10240 * 1024 * 1024) - local traffic session limit
  $trafic_limit = ($trafic_limits{1} > 10240) ? 10240 :  $trafic_limits{1};
  $EX_PARAMS{traf_limit_lo} = ($trafic_limit < 1 && $trafic_limit > 0) ? 1 : int($trafic_limit);
 }

 return \%EX_PARAMS;
}



#*******************************************************************
# returns:
#
#   -1 - No free adddress
#    0 - No address pool using nas servers ip address
#   192.168.101.1 - assign ip address
#
# get_ip($self, $nas_num, $nas_ip)
#*******************************************************************
sub get_ip {
 my $self = shift;
 my ($nas_num, $nas_ip) = @_;

 use IO::Socket;
 
#get ip pool
 $self->query($db, "SELECT ippools.ip, ippools.counts 
  FROM ippools
  WHERE ippools.nas='$nas_num';");

 if ($self->{TOTAL} < 1)  {
#     $self->{errno}=1;
#     $self->{errstr}='No ip pools';
     return 0;	
  }

 my %pools = ();
 my $list = $self->{list};
 foreach my $line (@$list) {
    my $sip   = $line->[0]; 
    my $count = $line->[1];

    for(my $i=$sip; $i<=$sip+$count; $i++) {
       $pools{$i}=undef;
     }
   }

#get active address and delete from pool

 $self->query($db, "SELECT framed_ip_address
  FROM calls 
  WHERE nas_ip_address=INET_ATON('$nas_ip') and (status=1 or status>=3);");

 $list = $self->{list};
 my %used_ips = ();
 while(my($ip) = each %$list) {
   if(exists($pools{$ip})) {
      delete($pools{$ip});
     }
   }
 
 my ($assign_ip, undef) = each(%pools);
 if ($assign_ip) {
   $assign_ip = inet_ntoa(pack('N', $assign_ip));
   return $assign_ip; 	
  }
 else { # no addresses available in pools
   return -1;
  }

 return 0;
}



#********************************************************************
# System auth function
# check_systemauth($user, $password)
#********************************************************************
sub check_systemauth {
 my ($user, $password)= @_;

 if ($< != 0) {
   log_print('LOG_ERR', "For system Authentification you need root privileges");
   exit 1;
  }

 my @pw = getpwnam("$user");

 if ($#pw < 0) {
    return 0;
  }
 
 my $salt = "$pw[1]";
 my $ep = crypt($password, $salt);

 if ($ep eq $pw[1]) {
    return 1;
  }
 else {
    return 0;
  }
}


#*******************************************************************
# Check chap password
# check_chap($given_password,$want_password,$given_chap_challenge,$debug) 
#*******************************************************************
sub check_chap {
 eval { require Digest::MD5; };
 if (! $@) {
    Digest::MD5->import();
   }
 else {
    log_print('LOG_ERR', "Can't load 'Digest::MD5' check http://www.cpan.org");
  }

my ($given_password,$want_password,$given_chap_challenge,$debug) = @_;

        $given_password =~ s/^0x//;
        $given_chap_challenge =~ s/^0x//;
        my $chap_password = pack("H*", $given_password);
        my $chap_challenge = pack("H*", $given_chap_challenge);
        my $md5 = new Digest::MD5;
        $md5->reset;
        $md5->add(substr($chap_password, 0, 1));
        $md5->add($want_password);
        $md5->add($chap_challenge);
        my $digest = $md5->digest();


        if ($digest eq substr($chap_password, 1)) { 
           return 1; 
          }
        else {
           return 0;
          }

}




#********************************************************************
# Get current time info
#   SESSION_START
#   DAY_BEGIN
#   DAY_OF_WEEK
#   DAY_OF_YEAR
#********************************************************************
sub get_timeinfo {
  my $self = shift;

  $self->query($db, "select
    UNIX_TIMESTAMP(),
    UNIX_TIMESTAMP(DATE_FORMAT(FROM_UNIXTIME(UNIX_TIMESTAMP()), '%Y-%m-%d')),
    DAYOFWEEK(FROM_UNIXTIME(UNIX_TIMESTAMP())),
    DAYOFYEAR(FROM_UNIXTIME(UNIX_TIMESTAMP()));");

  if($self->{errno}) {
    return $self;
   }
  my $a_ref = $self->{list}->[0];

 ($self->{SESSION_START},
  $self->{DAY_BEGIN},
  $self->{DAY_OF_WEEK},
  $self->{DAY_OF_YEAR})  = @$a_ref;

 return $self;
 }



#********************************************************************
# remaining_time
#  returns
#    -1 = access deny not allow day
#    -2 = access deny not allow hour
#********************************************************************
sub remaining_time {
  my ($self)=shift;
  my ($tp_id, $deposit, $session_start, 
  $day_begin, $day_of_week, $day_of_year,
  $attr) = @_;
  
  my %ATTR = ();

  if ($session_start + $day_begin + $day_of_week + $day_of_year == 0) {
  	 $self->get_timeinfo();
  	 $session_start = $self->{SESSION_START};
     $day_begin     = $self->{DAY_BEGIN};
     $day_of_week   = $self->{DAY_OF_WEEK};
     $day_of_year   = $self->{DAY_OF_YEAR};
   }

  my $debug = 0;
 
  my $time_limit = (defined($attr->{time_limit})) ? $attr->{time_limit} : 0;
  my $mainh_tarif = (defined($attr->{mainh_tarif})) ? $attr->{mainh_tarif} : 0;
  my $remaining_time = 0;

  use Billing;
  my $Billing = Billing->new($db);
  my ($time_intervals, $periods_time_tarif, $periods_traf_tarif) = $Billing->time_intervals($tp_id);

 if ($time_intervals == 0) {
    return 0;
    #return $deposit / $mainh_tarif * 60 * 60;	
  }
 
 my %holidays = ();
 if (defined($time_intervals->{8})) {
   use Tariffs;
   my $tariffs = Tariffs->new($db);
   my $list = $tariffs->holidays_list({ format => 'daysofyear' });
   foreach my $line (@$list) {
     $holidays{$line->[0]} = 1;
    }
  }


 my $tarif_day = 0;
 my $count = 0;
 $session_start = $session_start - $day_begin;

# print "$session_start 
#  $day_of_week, 
#  $day_of_year,\n";

#for($i = 0; $i< 100;$i++)
#    {
#   printf("%d\n", $i) ;
#        }
#   while ($i > 0)
#    {
#       printf("%d\n", $i-);
#    }
#   do {
#   printf("%d\n", $i++);
#      } while ($i < 0);

 while(($deposit > 0 && $count < 50)) {
  
   if ($time_limit != 0 && $time_limit < $remaining_time) {
     $remaining_time = $time_limit;
     last;
    }

   if(defined($holidays{$day_of_year}) && defined($time_intervals->{8})) {
    	#print "Holliday tarif '$day_of_year' ";
    	$tarif_day = 8;
    }
   elsif (defined($time_intervals->{$day_of_week})) {
    	#print "Day tarif '$day_of_week'";
    	$tarif_day = $day_of_week;
    }
   elsif(defined($time_intervals->{0})) {
      #print "Global tarif";
      $tarif_day = 0;
    }
   elsif($count > 0) {
      last;
    }
   else {
   	  return -1;
    }


  print "Count:  $count Remain Time: $remaining_time\n" if ($debug == 1);

  # Time check
  # $session_start

     $count++;

     my $cur_int = $time_intervals->{$tarif_day};
     my $i;
     my $prev_tarif = '';
     
     TIME_INTERVALS:

     my @intervals = sort keys %$cur_int; 
     $i = -1;

     foreach my $int_begin (@intervals) {
       my ($int_id, $int_end) = split(/:/, $cur_int->{$int_begin}, 2);
       $i++;

       my $price = 0;
       my $int_prepaid = 0;
       my $int_duration = 0;

       print "Day: $tarif_day Session_start: $session_start => Int Begin: $int_begin End: $int_end Int ID: $int_id\n" if ($debug == 1);

       if ($int_begin <= $session_start && $session_start < $int_end) {
          $int_duration = $int_end-$session_start;
          
          print " <<=\n" if ($debug == 1);    
          # if defined prev_tarif
          if ($prev_tarif ne '') {
            	my ($p_day, $p_begin)=split(/:/, $prev_tarif, 2);
            	$int_end=$p_begin;
            	print "Prev tarif $prev_tarif / INT end: $int_end \n" if ($debug == 1);
           }

          
          
          if ($periods_time_tarif->{$int_id} =~ /%$/) {
             my $tp = $periods_time_tarif->{$int_id};
             $tp =~ s/\%//;
             $price = $mainh_tarif  * ($tp / 100);
           }
          else {
             $price = $periods_time_tarif->{$int_id};
           }

          if($periods_traf_tarif->{$int_id} > 0 && $remaining_time == 0) {
            print "This tarif with traffic counts\n" if ($debug == 1);
            $ATTR{TT}=$int_id;
            return int($int_duration), \%ATTR;
           }
          elsif($periods_traf_tarif->{$int_id} > 0) {
            print "Next tarif with traffic counts  $int_end {$tarif_day} {$int_begin}\n" if ($debug == 1);
            return int($remaining_time), \%ATTR;
           }
          elsif ($price > 0) {
            $int_prepaid = $deposit / $price * 3600;
           }
          else {
            $int_prepaid = $int_duration;	
           }
          #print "Int Begin: $int_begin Int duration: $int_duration Int prepaid: $int_prepaid Prise: $price\n";



          if ($int_prepaid >= $int_duration) {
            $deposit -= ($int_duration / 3600 * $price);
            $session_start += $int_duration;
            $remaining_time += $int_duration;
            #print "DP $deposit ($int_prepaid > $int_duration) $session_start\n";
           }
          elsif($int_prepaid <= $int_duration) {
            $deposit =  0;    	
            $session_start += $int_prepaid;
            $remaining_time += $int_prepaid;
            #print "DL '$deposit' ($int_prepaid <= $int_duration) $session_start\n";
           }
        }
       elsif($i == $#intervals) {
       	  print "!! LAST@@@@ $i == $#intervals\n" if ($debug == 1);
       	  $prev_tarif = "$tarif_day:$int_begin";

       	  if (defined($time_intervals->{0}) && $tarif_day != 0) {
       	    $tarif_day = 0;
       	    $cur_int = $time_intervals->{$tarif_day};
       	    print "Go to\n" if ($debug == 1);
       	    goto TIME_INTERVALS;
       	   }
       	  elsif($session_start < 86400) {
      	  	 if ($remaining_time > 0) {
      	  	   return int($remaining_time);
      	  	  }
             else {
             	 # Not allow hour
             	 # return -2;
              }
      	   }
       	  #return $remaining_time;
       	  next;
        }
      }

  return -2 if ($remaining_time == 0);
  
  if ($session_start >= 86400) {
    $session_start=0;
    $day_of_week = ($day_of_week + 1 > 7) ? 1 : $day_of_week+1;
    $day_of_year = ($day_of_year + 1 > 365) ? 1 : $day_of_year + 1;
   }
#  else {
#  	return int($remaining_time), \%ATTR;
#   }
 
 }

return int($remaining_time), \%ATTR;
}



#***********************************************************
# bin2hex()
#***********************************************************
sub bin2hex ($) {
 my $bin = shift;
 my $hex = '';
 
 for my $c (unpack("H*",$bin)){
   $hex .= $c;
 }

 return $hex;
}



#*******************************************************************
# Authorization module
# pre_auth()
#*******************************************************************
sub pre_auth {
  my ($self, $RAD, $attr)=@_;

if (! $RAD->{MS_CHAP_CHALLENGE}) {
  print "Auth-Type := Accept\n";
  exit 0;
 }

  $self->query($db, "SELECT DECODE(password, '$attr->{SECRETKEY}') FROM users WHERE id='$RAD->{USER_NAME}';");

  my $a = `echo "'$attr->{SECRETKEY}') FROM users WHERE id='$RAD->{USER_NAME}' test" > /tmp/aaaaaaa`;

  if ($self->{TOTAL} > 0) {
  	my $list = $self->{list}->[0];
    my $password = $list->[0];
    print "User-Password == \"$password\"";
    exit 0;
   }



  $self->{errno} = 1;
  $self->{errstr} = "USER: '$RAD->{USER_NAME}' not exist";
  exit 1;
}




#####################################################################
# Overrideable function that checks a MSCHAP password response
# $p is the current request
# $username is the users (rewritten) name
# $pw is the ascii plaintext version of the correct password if known
# rfc2548 Microsoft Vendor-specific RADIUS Attributes
sub check_mschap {
  my ($pw, $challenge, $response, $usersessionkeydest, $lanmansessionkeydest, $message) = @_;

  #use lib $Bin;
  use Abills::MSCHAP;

  $response =~ s/^0x//; 
  $challenge =~ s/^0x//;
  $challenge = pack("H*", $challenge);
  $response = pack("H*", $response);
  my($ident, $flags, $lmresponse, $ntresponse) = unpack('C C a24 a24', $response);


  if ($flags == 1) {
    my $upw = Radius::MSCHAP::ASCIItoUnicode($pw);
    #return Radius::MSCHAP::NtChallengeResponse($challenge, $upw);
    return unless Radius::MSCHAP::NtChallengeResponse($challenge, $upw) eq $ntresponse;
    # Maybe generate a session key. 
    
    $$usersessionkeydest = Radius::MSCHAP::NtPasswordHash(Radius::MSCHAP::NtPasswordHash($upw))
	if defined $usersessionkeydest;
    $$lanmansessionkeydest = Radius::MSCHAP::LmPasswordHash($pw)
	if defined $lanmansessionkeydest;

#      $RAD_PAIRS{'MS-CHAP-MPPE-Keys'} = '0x' . unpack("H*", (pack('a8 a16', Radius::MSCHAP::LmPasswordHash($pw), 
#                                                                            Radius::MSCHAP::NtPasswordHash( Radius::MSCHAP::NtPasswordHash(Radius::MSCHAP::ASCIItoUnicode($pw)))))). "0000000000000000";
   }
  else {
     $$message = "MS-CHAP LM-response not implemented";
     #log_print('LOG_ERR', "MS-CHAP LM-response not implemented");
     return 0;
   }
  
  return 1;

}



#####################################################################
# $p is the current request
# Overrideable function that checks a MSCHAP password response
# $username is the users (rewritten) name
# $pw is the ascii plaintext version of the correct password if known
# $sessionkeydest is a ref to a string where the sesiosn key for MPPE will be returned
sub check_mschapv2 {
    my ($username, $pw, $challenge, $peerchallenge, $response, $ident,
	$usersessionkeydest, $lanmansessionkeydest,  $ms_chap2_success) = @_;

  use Abills::MSCHAP;

  my $upw = Radius::MSCHAP::ASCIItoUnicode($pw);
  return 
  unless &Radius::MSCHAP::GenerateNTResponse($challenge, $peerchallenge, $username, $upw) 
	       eq $response;


    # Maybe generate a session key. 
    $$usersessionkeydest = Radius::MSCHAP::NtPasswordHash
	(Radius::MSCHAP::NtPasswordHash($upw))
	if defined $usersessionkeydest;
    $$lanmansessionkeydest = Radius::MSCHAP::LmPasswordHash($pw)
	if defined $lanmansessionkeydest;

   
    $$ms_chap2_success=pack('C a42', $ident,
			  &Radius::MSCHAP::GenerateAuthenticatorResponseHash
			  ($$usersessionkeydest, $response, $peerchallenge, $challenge, "$username"))
			  if defined $ms_chap2_success;


    return 1;
}











1

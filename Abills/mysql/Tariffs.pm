package Tariffs;
# Tarif plans functions
#

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
);

use Exporter;
$VERSION = 2.00;
@ISA = ('Exporter');

@EXPORT = qw(
);

@EXPORT_OK = ();
%EXPORT_TAGS = ();

use main;
@ISA  = ("main");

my $db;
my %DATA;


my %FIELDS = ( TP_ID => 'id', 
               NAME => 'name',  
               BEGIN => 'ut',
               END  => 'dt',  
               TIME_TARIF  => 'hourp',
               DAY_FEE => 'day_fee',
               MONTH_FEE => 'month_fee',
               SIMULTANEOUSLY => 'logins',
               AGE => 'age',
               DAY_TIME_LIMIT => 'day_time_limit',
               WEEK_TIME_LIMIT => 'week_time_limit',
               MONTH_TIME_LIMIT => 'month_time_limit',
               DAY_TRAF_LIMIT => 'day_traf_limit',  
               WEEK_TRAF_LIMIT => 'week_traf_limit',
               MONTH_TRAF_LIMIT => 'month_traf_limit',
               ACTIV_PRICE => 'activate_price',
               CHANGE_PRICE => 'change_price', 
               CREDIT_TRESSHOLD => 'credit_tresshold',
               ALERT => 'uplimit',
               OCTETS_DIRECTION => 'octets_direction',
               MAX_SESSION_DURATION => 'max_session_duration',
               FILTER_ID => ''
             );

#**********************************************************
# Init 
#**********************************************************
sub new {
  my $class = shift;
  $db = shift;
  my $self = { };
  bless($self, $class);
  return $self;
}




#**********************************************************
# Time_intervals
# ti_add
#**********************************************************
sub ti_del {
	my $self = shift;
	my ($id) = @_;
	$self->query($db, "DELETE FROM intervals WHERE id='$id';", 'do');
	return $self;
}


#**********************************************************
# Time_intervals
# ti_add
#**********************************************************
sub ti_add {
	my $self = shift;
	my ($attr) = @_;
	$self->query($db, "INSERT INTO intervals (tp_id, day, begin, end, tarif)
     values ('$self->{TP_ID}', '$attr->{TI_DAY}', '$attr->{TI_BEGIN}', '$attr->{TI_END}', '$attr->{TI_TARIF}');", 'do');
	return $self;
}

#**********************************************************
# Time_intervals  list
# ti_list
#**********************************************************
sub ti_list {
	my $self = shift;
	my ($attr) = @_;

  $self->query($db, "SELECT tp_id, day, begin, end, tarif, id
    FROM intervals WHERE tp_id='$self->{TP_ID}'");

	return $self->{list};
}

#**********************************************************
# tt_defaults
#**********************************************************
sub  ti_defaults {
	my $self = shift;
	
	my %TI_DEFAULTS = (
            TI_DAY => 0,
            TI_BEGIN => '00:00:00',
            TI_END => '24:00:00',
    	      TI_TARIF => 0
    );
	
  while(my($k, $v) = each %TI_DEFAULTS) {
    $self->{$k}=$v;
   }	
	
  #$self = \%DATA;
	return $self;
}


#**********************************************************
# Default values
#**********************************************************
sub defaults {
  my $self = shift;

  %DATA = ( TP_ID => 0, 
            NAME => '',  
            BEGIN => '00:00:00',
            END  => '24:00:00',    
            TIME_TARIF => '0.00000',
            DAY_FEE => '0,00',
            MONTH_FEE => '0.00',
            SIMULTANEOUSLY => 0,
            AGE => 0,
            DAY_TIME_LIMIT => 0,
            WEEK_TIME_LIMIT => 0,
            MONTH_TIME_LIMIT => 0,
            DAY_TRAF_LIMIT => 0, 
            WEEK_TRAF_LIMIT => 0, 
            MONTH_TRAF_LIMIT => 0,
            ACTIV_PRICE => '0.00',
            CHANGE_PRICE => '0.00',
            CREDIT_TRESSHOLD => '0.00',
            ALERT => 0,
            OCTETS_DIRECTION => 0,
            MAX_SESSION_DURATION => 0
         );   
 
  $self = \%DATA;
  return $self;
}


#**********************************************************
# Add
#**********************************************************
sub add {
  my $self = shift;
  my ($attr) = @_;

  %DATA = $self->get_data($attr, { default => \%DATA }); 

  $self->query($db, "INSERT INTO tarif_plans (id, hourp, uplimit, name, ut, dt, month_fee, day_fee, logins, 
     day_time_limit, week_time_limit,  month_time_limit, 
     day_traf_limit, week_traf_limit,  month_traf_limit,
     activate_price, change_price, credit_tresshold, age, octets_direction,
     max_session_duration, filter_id)
    values ('$DATA{TP_ID}', '$DATA{TIME_TARIF}', '$DATA{ALERT}', \"$DATA{NAME}\", '$DATA{END}', '$DATA{BEGIN}', 
     '$DATA{MONTH_FEE}', '$DATA{DAY_FEE}', '$DATA{SIMULTANEONSLY}', 
     '$DATA{DAY_TIME_LIMIT}', '$DATA{WEEK_TIME_LIMIT}',  '$DATA{MONTH_TIME_LIMIT}', 
     '$DATA{DAY_TRAF_LIMIT}', '$DATA{WEEK_TRAF_LIMIT}',  '$DATA{MONTH_TRAF_LIMIT}',
     '$DATA{ACTIV_PRICE}', '$DATA{CHANGE_PRICE}', '$DATA{CREDIT_TRESSHOLD}', '$DATA{AGE}', '$DATA{OCTETS_DIRECTION}',
     '$DATA{MAX_SESSION_DURATION}', '$DATA{FILTER_ID}');", 'do' );

  return $self;
}



#**********************************************************
# change
#**********************************************************
sub change {
  my $self = shift;
  my ($tp_id, $attr) = @_;
  
  %DATA = $self->get_data($attr); 
 
#  while(my($k, $v)=each(%DATA)) {
#  	 print "$k, $v<br>";
#   }
  
  my $CHANGES_QUERY = "";
  my $CHANGES_LOG = "Tarif plan:";
  
  my $OLD = $self->info($tp_id);

  while(my($k, $v)=each(%DATA)) {
    if ($OLD->{$k} ne $DATA{$k}){
      if ($FIELDS{$k}) {
         $CHANGES_LOG .= "$k $OLD->{$k}->$DATA{$k};";
         $CHANGES_QUERY .= "$FIELDS{$k}='$DATA{$k}',";
       }
     }
   }

if ($CHANGES_QUERY eq '') {
  return $self->{result};	
}

# print $CHANGES_LOG;
  chop($CHANGES_QUERY);
  $self->query($db, "UPDATE tarif_plans SET $CHANGES_QUERY
    WHERE id='$tp_id'", 'do');
  
  if ($tp_id == $DATA{TP_ID}) {
  	$self->info($tp_id);
   }
  else {
  	$self->info($DATA{TP_ID});
   }
  
#  $admin->action_add(0, "$CHANGES_LOG");
	return $self;
}

#**********************************************************
# del
#**********************************************************
sub del {
  my $self = shift;
  my ($id) = @_;
  	
  $self->query($db, "DELETE FROM tarif_plans WHERE id='$id';", 'do');

 return $self;
}

#**********************************************************
# Info
#**********************************************************
sub info {
  my $self = shift;
  my ($id) = @_;

  $self->query($db, "SELECT id, name, dt, ut, hourp, day_fee, month_fee, logins, age,
      day_time_limit, week_time_limit,  month_time_limit, 
      day_traf_limit, week_traf_limit,  month_traf_limit,
      activate_price, change_price, credit_tresshold, uplimit, octets_direction, max_session_duration
    FROM tarif_plans
    WHERE id='$id';");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  my $ar = $self->{list}->[0];
  
  ($self->{TP_ID}, 
   $self->{NAME}, 
   $self->{BEGIN}, 
   $self->{END}, 
   $self->{TIME_TARIF}, 
   $self->{DAY_FEE}, 
   $self->{MONTH_FEE}, 
   $self->{SIMULTANEOUSLY}, 
   $self->{AGE},
   $self->{DAY_TIME_LIMIT}, 
   $self->{WEEK_TIME_LIMIT}, 
   $self->{MONTH_TIME_LIMIT}, 
   $self->{DAY_TRAF_LIMIT}, 
   $self->{WEEK_TRAF_LIMIT}, 
   $self->{MONTH_TRAF_LIMIT}, 
   $self->{ACTIV_PRICE},    
   $self->{CHANGE_PRICE}, 
   $self->{CREDIT_TRESSHOLD},
   $self->{ALERT},
   $self->{OCTETS_DIRECTION},
   $self->{MAX_SESSION_DURATION},
   $self->{FILTER_ID}
  ) = @$ar;


  return $self;
}


#**********************************************************
# list
#**********************************************************
sub list {
  my $self = shift;
  my ($attr) = @_;

 my $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 my $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';

 my $WHERE = '';

 $self->query($db, "SELECT tp.id, tp.name, tp.dt, tp.ut, tp.hourp, if(sum(tt.in_price + tt.out_price)> 0, 1, 0), 
    tp.day_fee, tp.month_fee, tp.logins, tp.age
    FROM tarif_plans tp
    LEFT JOIN trafic_tarifs tt ON (tt.tp_id=tp.id)
    $WHERE
    GROUP BY tp.id
    ORDER BY $SORT $DESC;");

 return $self->{list};
}



#**********************************************************
# list_allow nass
#**********************************************************
sub nas_list {
  my $self = shift;
  $self->query($db, "SELECT nas_id FROM tp_nas WHERE tp_id='$self->{TP_ID}';");
	return $self->{list};
}

#**********************************************************
# list_allow nass
#**********************************************************
sub nas_add {
 my $self = shift;
 my ($nas) = @_;
 
 $self->nas_del();
 foreach my $line (@$nas) {
   $self->query($db, "INSERT INTO tp_nas (nas_id, tp_id)
        VALUES ('$line', '$self->{TP_ID}');", 'do');	
  }
  #$admin->action_add($uid, "NAS ". join(',', @$nas) );
  return $self;
}

#**********************************************************
# nas_del
#**********************************************************
sub nas_del {
  my $self = shift;
  $self->query($db, "DELETE FROM tp_nas WHERE tp_id='$self->{TP_ID}';", 'do');
  #$admin->action_add($uid, "DELETE NAS");
  return $self;
}


#**********************************************************
# tt_defaults
#**********************************************************
sub  tt_defaults {
	my $self = shift;
	
	my %TT_DEFAULTS = (
      TT_DESCRIBE_0 => '',
      TT_PRICE_IN_0 => '0.00000',
      TT_PRICE_OUT_0 => '0.00000',
      TT_NETS_0 => '0.0.0.0/0',
      TT_PREPAID_0 => 0,
      TT_SPEED_0 => 0,

      TT_DESCRIBE_1 => '',
      TT_PRICE_IN_1 => '0.00000',
      TT_PRICE_OUT_1 => '0.00000',
      TT_PRICE_NETS_1 => '',
      TT_PREPAID_1 => 0,
      TT_SPEED_1 => 0,

      TT_DESCRIBE_2 => '',
      TT_PRICE_IN_2 => 0,
      TT_PRICE_OUT_2 => 0,
      TT_NETS_2 => '',
      TT_PREPAID_2 => 0,
      TT_SPEED_2 => 0
     );
	
  while(my($k, $v) = each %TT_DEFAULTS) {
    $self->{$k}=$v;
   }	
	
  #$self = \%DATA;
	return $self;
}



#**********************************************************
# tt_info
#**********************************************************
sub  tt_list {
	my $self = shift;
	
	
	$self->query($db, "SELECT id, in_price, out_price, descr, prepaid, nets, speed
  FROM trafic_tarifs WHERE tp_id='$self->{TP_ID}';");

  my $a_ref = $self->{list};


  foreach my $row (@$a_ref) {
      my ($id, $tarif_in, $tarif_out, $describe, $prepaid, $nets, $speed) = @$row;
      $self->{'TT_DESCRIBE_'. $id} = $describe;
      $self->{'TT_PRICE_IN_' . $id} = $tarif_in;
      $self->{'TT_PRICE_OUT_' . $id} = $tarif_out;
      $self->{'TT_NETS_'.  $id} = $nets;
      $self->{'TT_PREPAID_' .$id} = $prepaid;
      $self->{'TT_SPEED_' .$id} = $speed;
   }
	
	return $self;
}


#**********************************************************
# tt_info
#**********************************************************
sub  tt_change {
  my $self = shift;
	my ($attr) = @_; 
  
  %DATA = $self->get_data($attr, {default => $self->tt_defaults() }); 
  my $file_path = (defined($attr->{EX_FILE_PATH})) ? $attr->{EX_FILE_PATH} : '';


my $body = "";
my @n = ();
$/ = chr(0x0d);

my $i=0;
for($i=0; $i<=2; $i++) {
  $self->query($db, "REPLACE trafic_tarifs SET 
    id='$i',
    descr='". $DATA{'TT_DESCRIBE_' . $i } ."', 
    in_price='". $DATA{'TT_PRICE_IN_'. $i}  ."',
    out_price='". $DATA{'TT_PRICE_OUT_'. $i} ."',
    nets='". $DATA{'TT_NETS_'. $i} ."',
    prepaid='". $DATA{'TT_PREPAID_'. $i} ."',
    speed='". $DATA{'TT_SPEED_'. $i} ."',
    tp_id='$self->{TP_ID}';", 'do');


  if ($DATA{'TT_NETS_'. $i} ne '') {
     @n = split(/\n|;/, $DATA{'TT_NETS_'. $i});
     foreach my $line (@n) {
       chomp($line);
       next if ($line eq "");
       $body .= "$line $i\n";
     }
   }

}

 $self->create_tt_file("$file_path", "$self->{TP_ID}.nets", "$body");
		
}

#**********************************************************
# create_tt_file()
#**********************************************************
sub create_tt_file {
 my ($self, $path, $file_name, $body) = @_;
 
 print "<pre>$body</pre>";
 
 open(FILE, ">$path/$file_name") || die "Can't create file '$path/$file_name' $!\n";
   print FILE "$body";
 close(FILE);
 
 return $self;
}


#**********************************************************
# holidays_list
#**********************************************************
sub holidays_list {
	my $self = shift;
  my ($attr) = @_;

  my $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
  my $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';

  my $year = (defined($attr->{year})) ? $attr->{year} : 'YEAR(CURRENT_DATE)';
  my $format = (defined($attr->{format}) && $attr->{format} eq 'daysofyear') ? "DAYOFYEAR(CONCAT($year, '-', day)) as dayofyear" : 'day';

  $self->query($db, "SELECT $format, descr  FROM holidays ORDER BY $SORT $DESC;");
	return $self->{list};
}


#**********************************************************
# holidays_list
#**********************************************************
sub holidays_add {
	my $self = shift;
	my ($attr)=@_;
	
	$DATA{MONTH} = (defined($attr->{MONTH})) ? $attr->{MONTH} : 1;
	$DATA{DAY} = (defined($attr->{DAY})) ? $attr->{DAY} : 1;
	
	$self->query($db,"INSERT INTO holidays (day)
       VALUES ('$DATA{MONTH}-$DATA{DAY}');", 'do');

  return $self;
}


#**********************************************************
# holidays_list
#**********************************************************
sub holidays_del {
	my $self = shift;
  my ($id) = @_;
	$self->query($db, "DELETE from holidays WHERE day='$id';", 'do');
  return $self;
}


1
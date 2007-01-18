package Dhcphosts;
# DHCP server managment and user control
#

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);


use Exporter;
$VERSION = 2.00;
@ISA = ('Exporter');

@EXPORT = qw();
@EXPORT_OK = ();
%EXPORT_TAGS = ();

use main;
@ISA  = ("main");

my $MODULE='Dhcphosts';


#**********************************************************
# Init 
#**********************************************************
sub new {
  my $class = shift;
  ($db, $admin, $CONF) = @_;

  $admin->{MODULE}=$MODULE;

  my $self = { };
  bless($self, $class);
 
  
  return $self;
}




#**********************************************************
# routes_list()
#**********************************************************
sub routes_list {
 my $self = shift;
 my ($attr) = @_;

 undef @WHERE_RULES;
 if ($attr->{NET_ID}) {
   push @WHERE_RULES, "r.network='$attr->{NET_ID}'"; 
 }
 if ($attr->{RID}) {
   push @WHERE_RULES, "r.id='$attr->{RID}'"; 
 }

 $WHERE = ($#WHERE_RULES > -1) ? "WHERE " . join(' and ', @WHERE_RULES)  : '';

 $self->query($db, "SELECT 
    r.id, r.network, inet_ntoa(r.src),
    INET_NTOA(r.mask),
    inet_ntoa(r.router),
    n.name
     FROM dhcphosts_routes r
     left join dhcphosts_networks n on r.network=n.id
     $WHERE
     ORDER BY $SORT $DESC LIMIT $PG, $PAGE_ROWS;");

 return $self if($self->{errno});


 my $list = $self->{list};

 if ($self->{TOTAL} > 0) {
    $self->query($db, "SELECT count(*) FROM dhcphosts_routes r $WHERE");
    ($self->{TOTAL}) = @{ $self->{list}->[0] };
  }

  return $list;
};



#**********************************************************
# network_add()
#**********************************************************
sub network_add {
  my $self=shift;
  my ($attr)=@_;


  $self->query($db,"INSERT INTO dhcphosts_networks 
     (name,network,mask,coordinator,phone, dns, suffix) 
     VALUES('$attr->{NAME}', INET_ATON('$attr->{NETWORK}'), INET_ATON('$attr->{MASK}'),
       '$attr->{COORDINATOR}', '$attr->{PHONE}', '$attr->{DNS}', '$attr->{DOMAINNAME}')", 'do');

  return $self;
}

#**********************************************************
# network_delete()
#**********************************************************
sub network_del {
  my $self=shift;
  my ($id)=@_;

  $self->query($db, "DELETE FROM dhcphosts_networks where id='$id';", 'do');

  return $self;
};


#**********************************************************
# network_update()
#**********************************************************sub change {
sub network_change {
  my $self = shift;
  my ($attr) = @_;

 
 my %FIELDS = (
   ID            => 'id',
   NAME          => 'name',
   NETWORK       => 'network',   
   MASK          => 'mask',
   BLOCK_NETWORK => 'block_network',
   BLOCK_MASK    => 'block_mask',
   DOMAINNAME    => 'suffix',
   DNS           => 'dns',
   COORDINATOR   => 'coordinator',
   PHONE         => 'phone'

   );

	$self->changes($admin, { CHANGE_PARAM => 'ID',
		               TABLE        => 'dhcphosts_networks',
		               FIELDS       => \%FIELDS,
		               OLD_INFO     => $self->network_info($attr->{ID}),
		               DATA         => $attr
		              } );


  return $self;
}


#**********************************************************
# Info
#**********************************************************
sub network_info {
  my $self = shift;
  my ($id) = @_;

  $self->query($db, "SELECT
   id,
   name,
   INET_NTOA(network),
   INET_NTOA(mask),
   INET_NTOA(block_network),
   INET_NTOA(block_mask),
   suffix,
   dns,
   coordinator,
   phone
  FROM dhcphosts_networks

  WHERE id='$id';");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{ID}, 
   $self->{NAME}, 
   $self->{NETWORK}, 
   $self->{MASK}, 
   $self->{BLOCK_NETWORK}, 
   $self->{BLOCK_MASK}, 
   $self->{DOMAINNAME}, 
   $self->{DNS},
   $self->{COORDINATOR},
   $self->{PHONE}
   ) = @{ $self->{list}->[0] };
    
  return $self;
}


#**********************************************************
# networks_list()
#**********************************************************
sub networks_list {
 my $self = shift;
 my ($attr) = @_;

 $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';
 $PG = ($attr->{PG}) ? $attr->{PG} : 0;
 $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;

 undef @WHERE_RULES;
 if ($attr->{ID}) {
   push @WHERE_RULES, "err_id='$attr->{ID}'"; 
 }

 $WHERE = ($#WHERE_RULES > -1) ? "WHERE " . join(' and ', @WHERE_RULES)  : '';
 
 $self->query($db, "SELECT 
    id,name,INET_NTOA(network),
     INET_NTOA(mask),
     coordinator,
     phone
     FROM dhcphosts_networks
     $WHERE
     ORDER BY $SORT $DESC LIMIT $PG, $PAGE_ROWS;");

 return $self if ($self->{errno});

 my $list = $self->{list};

 if ($self->{TOTAL} > 0) {
   $self->query($db, "SELECT count(*) FROM dhcphosts_networks $WHERE");
   ($self->{TOTAL}) = @{ $self->{list}->[0] };
  }

 return $list;
};



#**********************************************************
# host_defaults()
#**********************************************************
sub host_defaults {
  my $self = shift;

  my %DATA = (
   MAC            => '00:00:00:00:00:00', 
   EXPIRE         => '0000-00-00', 
   IP             => '0.0.0.0'
  );

 
  $self = \%DATA;
  return $self;
}
#**********************************************************
# host_add()
#**********************************************************
sub host_add {
  my $self=shift;
  my ($attr)=@_;

  my %DATA = $self->get_data($attr); 

  $self->query($db, "INSERT INTO dhcphosts_hosts (uid, hostname, network, ip, mac, blocktime, forced) 
    VALUES('$DATA{UID}', '$DATA{HOSTNAME}', '$DATA{NETWORK}',
      INET_ATON('$DATA{IP}'), '$DATA{MAC}', '$DATA{BLOCKTIME}', '$DATA{FORCED}');", 'do');

  return $self;
}

#**********************************************************
# host_delete()
#**********************************************************
sub host_del {
  my $self=shift;
  my ($id)=@_;

  $self->query($db,"DELETE FROM dhcphosts_hosts where id='$id'", 'do');

  return $self;
};

#**********************************************************
#route_update()
#**********************************************************
sub host_info {
  my $self=shift;
  my ($id)=@_;

  $self->query($db, "SELECT
   uid, 
   hostname, 
   network, 
   INET_NTOA(ip), 
   mac, 
   blocktime, 
   forced
  FROM dhcphosts_hosts
  WHERE id='$id';");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{UID}, 
   $self->{HOSTNAME}, 
   $self->{NETWORK}, 
   $self->{IP}, 
   $self->{MAC}, 
   $self->{BLOCKTIME}, 
   $self->{FORCED}
   ) = @{ $self->{list}->[0] };

  return $self;
};


#**********************************************************
#route_update()
#**********************************************************
sub host_change {
 my $self=shift;
 my ($attr) = @_;

 my %FIELDS = (
   ID          => 'id',
   UID         => 'uid',
   HOSTNAME    => 'hostname', 
   NETWORK     => 'network', 
   IP         => 'ip', 
   MAC         => 'mac', 
   BLOCKTIME   => 'blocktime', 
   FORCED      => 'forced'
  );

	$self->changes($admin, { CHANGE_PARAM => 'ID',
		               TABLE        => 'dhcphosts_hosts',
		               FIELDS       => \%FIELDS,
		               OLD_INFO     => $self->host_info($attr->{ID}),
		               DATA         => $attr
		              } );
  return $self;
};




#**********************************************************
# route_add()
#**********************************************************
sub route_add {
    my $self=shift;
    my ($attr) = @_;

    my %DATA = $self->get_data($attr); 

    $self->query($db, "INSERT INTO dhcphosts_routes 
       (network, src, mask, router) 
    values($DATA{NET_ID},INET_ATON('$DATA{SRC}'), INET_ATON('$DATA{MASK}'), INET_ATON('$DATA{ROUTER}'))", 'do');

    return $self;
};

#**********************************************************
# route_delete()
#**********************************************************
sub route_del {
  my $self=shift;
  my ($id)=@_;
  $self->query($db,"DELETE FROM dhcphosts_routes where id='$id'", 'do');

  return $self;
};


#**********************************************************
# route_update()
#**********************************************************
sub route_change {
    my $self=shift;
    my ($attr)=@_;

 my %FIELDS = (
   ID         => 'id',
   NET_ID     => 'network',
   SRC        => 'src', 
   MASK       => 'mask', 
   ROUTER     => 'router'
  );

	$self->changes($admin, { CHANGE_PARAM => 'ID',
		               TABLE        => 'dhcphosts_routes',
		               FIELDS       => \%FIELDS,
		               OLD_INFO     => $self->route_info($attr->{ID}),
		               DATA         => $attr
		              } );

  return $self if($self->{errno});
};

#**********************************************************
# route_update()
#**********************************************************
sub route_info {
  my $self=shift;
  my ($id)=@_;


  $self->query($db,"SELECT 
   id,
   network,
   INET_NTOA(src),
   INET_NTOA(mask),
   INET_NTOA(router)
 
   FROM dhcphosts_routes WHERE id='$id';");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{NET_ID}, 
   $self->{NETWORK}, 
   $self->{SRC}, 
   $self->{MASK}, 
   $self->{ROUTER}
   ) = @{ $self->{list}->[0] };


  return $self;
};



#**********************************************************
# hosts_list()
#**********************************************************
sub hosts_list {
 my $self = shift;
 my ($attr) = @_;

 $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';
 $PG = ($attr->{PG}) ? $attr->{PG} : 0;
 $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;

 undef @WHERE_RULES;
 if ($attr->{ID}) {
   push @WHERE_RULES, "h.id='$attr->{ID}'"; 
  }
 else {
  if ($attr->{UID}) {
	  push @WHERE_RULES, "h.uid='$attr->{UID}'"; 
   }
 }

 $WHERE = ($#WHERE_RULES > -1) ? "WHERE " . join(' and ', @WHERE_RULES)  : '';

 $self->query($db, "SELECT 
    h.id, u.id, INET_NTOA(h.ip), h.hostname, n.name, h.network, h.mac, h.block_date, h.forced, 
      h.blocktime, h.active, seen, h.uid
     FROM dhcphosts_hosts h
     left join dhcphosts_networks n on h.network=n.id
     left join users u on h.uid=u.uid
     $WHERE
     ORDER BY $SORT $DESC LIMIT $PG, $PAGE_ROWS;");

 return $self if($self->{errno});


 my $list = $self->{list};


 if ($self->{TOTAL} > 0) {
    $self->query($db, "SELECT count(*) FROM dhcphosts_hosts h $WHERE");
    ($self->{TOTAL}) = @{ $self->{list}->[0] };
  }

 return $list;
}






1



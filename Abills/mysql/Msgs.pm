package Msgs; # Message system #

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION
);

use Exporter;
$VERSION = 2.00;
@ISA = ('Exporter');

@EXPORT = qw();

@EXPORT_OK = ();
%EXPORT_TAGS = ();

use main;
@ISA  = ("main");

my $MODULE='Msgs';

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
# messages_list
#**********************************************************
sub messages_new {
  my $self = shift;
  my ($attr) = @_;


 my @WHERE_RULES = ();
 my $fields = '';
 
 if ($attr->{USER_READ}) {
   push @WHERE_RULES, "m.user_read='$attr->{USER_READ}' AND admin_read>'0000-00-00 00:00:00' AND m.inner_msg='0'"; 
   $fields='count(*)';
  }
 elsif ($attr->{ADMIN_READ}) {
 	 $fields = "sum(if(admin_read='0000-00-00 00:00:00', 1, 0)), 
 	  sum(if(plan_date=curdate(), 1, 0)),
 	  sum(if(state = 0, 1, 0))
 	   ";
   push @WHERE_RULES, "m.state=0";
  }

 if ($attr->{UID}) {
   push @WHERE_RULES, "m.uid='$attr->{UID}'"; 
 }

 if ($attr->{CHAPTERS}) {
   push @WHERE_RULES, "m.chapter IN ($attr->{CHAPTERS})"; 
  }

 if ($attr->{GIDS}) {
   push @WHERE_RULES, "u.gid IN ($attr->{GIDS})"; 
 }

 $WHERE = ($#WHERE_RULES > -1) ? 'WHERE '. join(' and ', @WHERE_RULES)  : '';

 if ($attr->{GIDS}) {
   $self->query($db,   "SELECT $fields 
    FROM (msgs_messages m, users u)
   $WHERE and u.uid=m.uid;");
  }
 else {
   $self->query($db,   "SELECT $fields 
    FROM (msgs_messages m)
   $WHERE;");
  }

 ($self->{UNREAD}, $self->{TODAY}, $self->{OPENED}) = @{ $self->{list}->[0] };

  return $self;	
}

#**********************************************************
# messages_list
#**********************************************************
sub messages_list {
 my $self = shift;
 my ($attr) = @_;

 
 $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;
 $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 $DESC = (defined($attr->{DESC})) ? $attr->{DESC} : 'DESC';


 @WHERE_RULES = ();
 
 if($attr->{LOGIN_EXPR}) {
	 push @WHERE_RULES, @{ $self->search_expr($attr->{LOGIN_EXPR}, 'STR', 'u.id') };
  }
 
 if ($attr->{DATE}) {
   push @WHERE_RULES, "date_format(m.date, '%Y-%m-%d')='$attr->{DATE}'";
  } 
 elsif ($attr->{FROM_DATE}) {
   push @WHERE_RULES, "(date_format(m.date, '%Y-%m-%d')>='$attr->{FROM_DATE}' and date_format(m.date, '%Y-%m-%d')<='$attr->{TO_DATE}')";
  }

 if (defined($attr->{INNER_MSG})) {
 	 push @WHERE_RULES, "m.inner_msg='$attr->{INNER_MSG}'"; 
  }

 if ($attr->{PLAN_FROM_DATE}) {
    push @WHERE_RULES, "(date_format(m.plan_date, '%Y-%m-%d')>='$attr->{PLAN_FROM_DATE}' and date_format(m.plan_date, '%Y-%m-%d')<='$attr->{PLAN_TO_DATE}')";
  }
 elsif ($attr->{PLAN_WEEK}) {
    push @WHERE_RULES, "(WEEK(m.plan_date)=WEEK(curdate()) and date_format(m.plan_date, '%Y')=date_format(curdate(), '%Y'))";
  }
 elsif ($attr->{PLAN_MONTH}) {
    push @WHERE_RULES, "date_format(m.plan_date, '%Y-%m')=date_format(curdate(), '%Y-%m')";
  }

 if ($attr->{MSG_ID}) {
 	  push @WHERE_RULES,  @{ $self->search_expr($attr->{MSG_ID}, 'INT', 'm.id') };
  }

 if (defined($attr->{REPLY})) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{USER_READ}, 'STR', 'm.user_read') };
  }

 if (defined($attr->{PHONE})) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{PHONE}, 'STR', 'm.phone') };
  }


 # Show groups
 if ($attr->{GIDS}) {
   push @WHERE_RULES, "u.gid IN ($attr->{GIDS})"; 
  }
 elsif ($attr->{GID}) {
   push @WHERE_RULES, "u.gid='$attr->{GID}'"; 
  }

 if ($attr->{USER_READ}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{USER_READ}, 'INT', 'm.user_read') };
  }

 if ($attr->{ADMIN_READ}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{ADMIN_READ}, 'INT', 'm.admin_read') };
  }

 if ($attr->{CLOSED_DATE}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{CLOSED_DATE}, 'INT', 'm.closed_date') };
  }

 if ($attr->{DONE_DATE}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{DONE_DATE}, 'INT', 'm.done_date') };
  }

 if ($attr->{REPLY_COUNT}) {
   #push @WHERE_RULES, "r.admin_read='$attr->{ADMIN_READ}'";
  }

 if ($attr->{CHAPTERS}) {
   push @WHERE_RULES, "m.chapter IN ($attr->{CHAPTERS})"; 
  }
 
 if ($attr->{UID}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{UID}, 'INT', 'm.uid') };
 }

 if (defined($attr->{STATE})) {
   if ($attr->{STATE} == 4) {
   	 push @WHERE_RULES, @{ $self->search_expr('0000-00-00 00:00:00', 'INT', 'm.admin_read') };
    }
   else {
     push @WHERE_RULES, @{ $self->search_expr($attr->{STATE}, 'INT', 'm.state')  };
    }
  }

 if ($attr->{PRIORITY}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{PRIORITY}, 'INT', 'm.state') };
  }

 if ($attr->{PLAN_DATE}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{PLAN_DATE}, 'INT', 'm.plan_date') };
  }

 if ($attr->{PLAN_TIME}) {
   push @WHERE_RULES,  @{ $self->search_expr($attr->{PLAN_TIME}, 'INT', 'm.plan_time') };
  }
 

 $WHERE = ($#WHERE_RULES > -1) ? 'WHERE '. join(' and ', @WHERE_RULES)  : '';


  $self->query($db,   "SELECT m.id,
if(m.uid>0, u.id, g.name),
m.subject,
mc.name,
m.date,
m.state,
inet_ntoa(m.ip),
a.id,
m.priority,
CONCAT(m.plan_date, ' ', m.plan_time),
SEC_TO_TIME(sum(r.run_time)),
m.uid,
a.aid,
m.state,
m.gid,
m.user_read,
m.admin_read,
if(r.id IS NULL, 0, count(r.id)),
m.chapter,
DATE_FORMAT(plan_date, '%w')


FROM (msgs_messages m)
LEFT JOIN users u ON (m.uid=u.uid)
LEFT JOIN admins a ON (m.aid=a.aid)
LEFT JOIN groups g ON (m.gid=g.gid)
LEFT JOIN msgs_reply r ON (m.id=r.main_msg)
LEFT JOIN msgs_chapters mc ON (m.chapter=mc.id)
 $WHERE
GROUP BY m.id 
    ORDER BY $SORT $DESC
    LIMIT $PG, $PAGE_ROWS;");


 my $list = $self->{list};

 if ($self->{TOTAL} > 0  || $PG > 0) {
   
   $self->query($db, "SELECT count(DISTINCT m.id), 
   sum(if(m.admin_read = '0000-00-00 00:00:00', 1, 0)),
   sum(if(m.state = 0, 1, 0)),
   sum(if(m.state = 1, 1, 0)),
   sum(if(m.state = 2, 1, 0))
    FROM (msgs_messages m)
    LEFT JOIN users u ON (m.uid=u.uid)
    LEFT JOIN msgs_chapters mc ON (m.chapter=mc.id)
    $WHERE");

   ($self->{TOTAL},
    $self->{IN_WORK},
    $self->{OPEN},
    $self->{UNMAKED},
    $self->{CLOSED},
    ) = @{ $self->{list}->[0] };
  }
 


 $WHERE = '';
 @WHERE_RULES=();
  
 return $list;
}


#**********************************************************
# Message
#**********************************************************
sub message_add {
	my $self = shift;
	my ($attr) = @_;

  %DATA = $self->get_data($attr, { default => \%DATA }); 

  my $CLOSED_DATE = ($DATA{STATE} == 1 || $DATA{STATE} == 2 ) ? 'now()' : "'0000-00-00 00:00:00'";

  $self->query($db, "insert into msgs_messages (uid, subject, chapter, message, ip, date, reply, aid, state, gid,
   priority, lock_msg, plan_date, plan_time, user_read, admin_read, inner_msg, resposible, closed_date,
   phone)
    values ('$DATA{UID}', '$DATA{SUBJECT}', '$DATA{CHAPTER}', '$DATA{MESSAGE}', INET_ATON('$DATA{IP}'), now(), 
        '$DATA{REPLY}',
        '$admin->{AID}',
        '$DATA{STATE}', 
        '$DATA{GID}',
        '$DATA{PRIORITY}',
        '$DATA{LOCK}',
        '$DATA{PLAN_DATE}',
        '$DATA{PLAN_TIME}',
        '$DATA{USER_READ}',
        '$DATA{ADMIN_READ}',
        '$DATA{INNER_MSG}',
        '$DATA{RESPOSIBLE}',
        $CLOSED_DATE,
        '$DATA{PHONE}'
        );", 'do');

  $self->{MSG_ID} = $self->{INSERT_ID};
  
	return $self;
}





#**********************************************************
# Bill
#**********************************************************
sub message_del {
	my $self = shift;
	my ($attr) = @_;

  @WHERE_RULES=();

  if ($attr->{ID}) {
    if ($attr->{ID} =~ /,/) {
    	push @WHERE_RULES, "id IN ($attr->{ID})";
     }
  	else {
  		push @WHERE_RULES, "id='$attr->{ID}'";
  	 }
   }



  if ($attr->{UID}) {
  	 push @WHERE_RULES, "uid='$attr->{UID}'";
  	
   }

  $WHERE = ($#WHERE_RULES > -1) ? join(' and ', @WHERE_RULES)  : '';
  $self->query($db, "DELETE FROM msgs_messages WHERE $WHERE", 'do');

  $self->message_reply_del({ MAIN_MSG => $attr->{ID} });
  $self->query($db, "DELETE FROM msgs_attachments WHERE message_id='$attr->{ID}' and message_type=0", 'do');

	return $self;
}

#**********************************************************
# Bill
#**********************************************************
sub message_info {
	my $self = shift;
	my ($id, $attr) = @_;

  $WHERE = ($attr->{UID}) ? "and m.uid='$attr->{UID}'" : '';

  $self->query($db, "SELECT m.id,
  m.subject,
  m.par,
  m.uid,
  m.chapter,
  m.message,
  m.reply,
  INET_NTOA(m.ip),
  m.date,
  m.state,
  m.aid,
  u.id,
  a.id,
  mc.name,
  m.gid,
  g.name,
  m.state,
  m.priority,
  m.lock_msg,
  m.plan_date,
  m.plan_time,
  m.closed_date,
  m.done_date,
  m.user_read,
  m.admin_read,
  m.resposible,
  m.inner_msg,
  m.phone
    FROM (msgs_messages m)
    LEFT JOIN msgs_chapters mc ON (m.chapter=mc.id)
    LEFT JOIN users u ON (m.uid=u.uid)
    LEFT JOIN admins a ON (m.aid=a.aid)
    LEFT JOIN groups g ON (m.gid=g.gid)
  WHERE m.id='$id' $WHERE
  GROUP BY m.id;");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{ID}, 
   $self->{SUBJECT},
   $self->{PARENT_ID},
   $self->{UID},
   $self->{CHAPTER},
   $self->{MESSAGE},
   $self->{REPLY},
   $self->{IP},
   $self->{DATE}, 
   $self->{STATE}, 
   $self->{AID},
   $self->{LOGIN},
   $self->{A_NAME},
   $self->{CHAPTER_NAME},
   $self->{GID},
   $self->{G_NAME},
   $self->{STATE},
   $self->{PRIORITY},
   $self->{LOCK},
   $self->{PLAN_DATE},
   $self->{PLAN_TIME},
   $self->{CLOSED_DATE},
   $self->{DONE_DATE},
   $self->{USER_READ},
 	 $self->{ADMIN_READ},
 	 $self->{RESPOSIBLE},
 	 $self->{INNER_MSG},
 	 $self->{PHONE}
  )= @{ $self->{list}->[0] };
	
	
  $self->attachment_info({ MSG_ID => $self->{ID} });

	return $self;
}


#**********************************************************
# change()
#**********************************************************
sub message_change {
  my $self = shift;
  my ($attr) = @_;
  
 
  my %FIELDS = (ID          => 'id',
                PARENT_ID   => 'par',
                UID			    => 'uid',
                CHAPTER     => 'chapter',
                MESSAGE     => 'message',
                REPLY       => 'reply',
                IP					=> 'ip',
                DATE        => 'date',
                STATE			  => 'state',
                AID         => 'aid',
                GID         => 'gid',
                PRIORITY    => 'priority',
                LOCK        => 'lock_msg',
                PLAN_DATE   => 'plan_date',
                PLAN_TIME   => 'plan_time',
                CLOSED_DATE => 'closed_date',
                DONE_DATE   => 'done_date',
                USER_READ   => 'user_read',
 	              ADMIN_READ  => 'admin_read',
 	              RESPOSIBLE  => 'resposible',
 	              INNER_MSG   => 'inner_msg',
 	              PHONE       => 'phone'
             );

  #print "!! $attr->{STATE} !!!";

  $admin->{MODULE}=$MODULE;
  $self->changes($admin,  { CHANGE_PARAM => 'ID',
                   TABLE        => 'msgs_messages',
                   FIELDS       => \%FIELDS,
                   OLD_INFO     => $self->message_info($attr->{ID}),
                   DATA         => $attr,
                   EXT_CHANGE_INFO  => "MSG_ID:$attr->{ID}"
                  } );

  return $self->{result};
}





#**********************************************************
# accounts_list
#**********************************************************
sub chapters_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
  $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';

  @WHERE_RULES = ();
 
 if($attr->{NAME}) {
	 push @WHERE_RULES, "mc.name='$attr->{NAME}'"; 
  }

 if($attr->{CHAPTERS}) {
	 push @WHERE_RULES, "mc.id IN ($attr->{CHAPTERS})"; 
  }

 if(defined($attr->{INNER_CHAPTER})) {
	 push @WHERE_RULES, "mc.inner_chapter IN ($attr->{INNER_CHAPTER})"; 
  }

 
 $WHERE = ($#WHERE_RULES > -1) ? 'WHERE ' . join(' and ', @WHERE_RULES)  : '';


  $self->query($db,   "SELECT mc.id, mc.name, mc.inner_chapter
    FROM msgs_chapters mc
    $WHERE
    GROUP BY mc.id 
    ORDER BY $SORT $DESC;");

 my $list = $self->{list};

# if ($self->{TOTAL} > 0 ) {
#   $self->query($db, "SELECT count(*)
#     FROM msgs_chapters mc
#     $WHERE");
#
#   ($self->{TOTAL}) = @{ $self->{list}->[0] };
#  }
 
 
	return $list;
}


#**********************************************************
# chapter_add
#**********************************************************
sub chapter_add {
	my $self = shift;
	my ($attr) = @_;
  
 
  %DATA = $self->get_data($attr, { default => \%DATA }); 
 

  $self->query($db, "insert into msgs_chapters (name, inner_chapter)
    values ('$DATA{NAME}', '$DATA{INNER_CHAPTER}');", 'do');

 
  $admin->system_action_add("MGSG_CHAPTER:$self->{INSERT_ID}", { TYPE => 1 });
	return $self;
}




#**********************************************************
# chapter_del
#**********************************************************
sub chapter_del {
	my $self = shift;
	my ($attr) = @_;

  @WHERE_RULES=();

  if ($attr->{ID}) {
  	 push @WHERE_RULES, "id='$attr->{ID}'";
   }

  $WHERE = ($#WHERE_RULES > -1) ? join(' and ', @WHERE_RULES)  : '';
  $self->query($db, "DELETE FROM msgs_chapters WHERE $WHERE", 'do');

	return $self;
}

#**********************************************************
# Bill
#**********************************************************
sub chapter_info {
	my $self = shift;
	my ($id, $attr) = @_;


  $self->query($db, "SELECT id,  name, inner_chapter
    FROM msgs_chapters 
  WHERE id='$id'");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{ID}, 
   $self->{NAME},
   $self->{INNER_CHAPTER}
  )= @{ $self->{list}->[0] };

	return $self;
}


#**********************************************************
# change()
#**********************************************************
sub chapter_change {
  my $self = shift;
  my ($attr) = @_;
  
  $attr->{INNER_CHAPTER} = ($attr->{INNER_CHAPTER}) ? 1 : 0;
  
  my %FIELDS = (ID            => 'id',
                NAME          => 'name',
                INNER_CHAPTER => 'inner_chapter'
             );

  $admin->{MODULE}=$MODULE;
  $self->changes($admin,  { CHANGE_PARAM => 'ID',
                   TABLE        => 'msgs_chapters',
                   FIELDS       => \%FIELDS,
                   OLD_INFO     => $self->chapter_info($attr->{ID}),
                   DATA         => $attr,
                   
                  } );

  return $self->{result};
}


#**********************************************************
# accounts_list
#**********************************************************
sub admins_list {
  my $self = shift;
  my ($attr) = @_;

  $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
  $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';

  @WHERE_RULES = ();
 
 if($attr->{AID}) {
	 push @WHERE_RULES, "ma.aid='$attr->{AID}'"; 
  }

 if($attr->{EMAIL_NOTIFY}) {
	 push @WHERE_RULES, "ma.email_notify='$attr->{EMAIL_NOTIFY}'"; 
  }

 if($attr->{EMAIL}) {
 	 $attr->{EMAIL} =~ s/\*/\%/ig;
	 push @WHERE_RULES, "a.email LIKE '$attr->{EMAIL}'"; 
  }

 if($attr->{CHAPTER_ID}) {
   my $value = $self->search_expr($attr->{CHAPTER_ID}, 'INT');
 	 push @WHERE_RULES, "ma.chapter_id$value"; 
  }
 
 
 $WHERE = ($#WHERE_RULES > -1) ? 'WHERE ' . join(' and ', @WHERE_RULES)  : '';


  $self->query($db, "SELECT a.id, mc.name, ma.priority, 0, a.aid, if(ma.chapter_id IS NULL, 0, ma.chapter_id), ma.email_notify, a.email
    FROM admins a 
    LEFT join msgs_admins ma ON (a.aid=ma.aid)
    LEFT join msgs_chapters mc ON (ma.chapter_id=mc.id)
    $WHERE
    ORDER BY $SORT $DESC;");

 my $list = $self->{list};

# if ($self->{TOTAL} > 0) {
#   $self->query($db, "SELECT count(*)
#     FROM msgs_chapters mc
#     $WHERE");

#   ($self->{TOTAL}) = @{ $self->{list}->[0] };
#  }
 
 
	return $list;
}


#**********************************************************
# chapter_add
#**********************************************************
sub admin_change {
	my $self = shift;
	my ($attr) = @_;
  
  my %DATA = $self->get_data($attr, { default => \%DATA }); 

  $self->admin_del({ AID => $attr->{AID}});
  
  my @chapters = split(/, /, $attr->{IDS});
  foreach my $id (@chapters) {
    $self->query($db, "insert into msgs_admins (aid, chapter_id, priority, email_notify)
      values ('$DATA{AID}', '$id','". $DATA{'PRIORITY_'. $id}."','". $DATA{'EMAIL_NOTIFY_'. $id}."');", 'do');
   }

	return $self;
}




#**********************************************************
# chapter_del
#**********************************************************
sub admin_del {
	my $self = shift;
	my ($attr) = @_;

  $self->query($db, "DELETE FROM msgs_admins WHERE aid='$attr->{AID}'", 'do');

	return $self;
}

#**********************************************************
# Bill
#**********************************************************
sub admin_info {
	my $self = shift;
	my ($id, $attr) = @_;


  $self->query($db, "SELECT id,  name
    FROM msgs_chapters 
  WHERE id='$id'");

  if ($self->{TOTAL} < 1) {
     $self->{errno} = 2;
     $self->{errstr} = 'ERROR_NOT_EXIST';
     return $self;
   }

  ($self->{ID}, 
   $self->{NAME}
  )= @{ $self->{list}->[0] };

	return $self;
}


#**********************************************************
# message_reply_del
#**********************************************************
sub message_reply_del {
	my $self = shift;
	my ($attr) = @_;

  @WHERE_RULES=();


  if($attr->{MAIN_MSG}) {
    if ($attr->{MAIN_MSG} =~ /,/) {
    	push @WHERE_RULES, "main_msg IN ($attr->{MAIN_MSG})";
     }
  	else {
  		push @WHERE_RULES, "main_msg='$attr->{MAIN_MSG}'";
  	 }
   }
  elsif ($attr->{ID}) {
    push @WHERE_RULES, "id='$attr->{ID}'";
    $self->query($db, "DELETE FROM msgs_attachments WHERE message_id='$attr->{ID}' and message_type=1", 'do');
   }

  my $WHERE = ($#WHERE_RULES > -1) ? join(' and ', @WHERE_RULES)  : '';
  $self->query($db, "DELETE FROM msgs_reply WHERE $WHERE", 'do');
  


	return $self;
}



#**********************************************************
# messages_list
#**********************************************************
sub messages_reply_list {
  my $self = shift;
  my ($attr) = @_;


 $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 25;
 $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 $DESC = (defined($attr->{DESC})) ? $attr->{DESC} : 'DESC';


 @WHERE_RULES = ();
 
 if($attr->{LOGIN_EXPR}) {
	 push @WHERE_RULES, "u.id='$attr->{LOGIN_EXPR}'"; 
  }
 
 if ($attr->{FROM_DATE}) {
    push @WHERE_RULES, "(date_format(m.date, '%Y-%m-%d')>='$attr->{FROM_DATE}' and date_format(m.date, '%Y-%m-%d')<='$attr->{TO_DATE}')";
  }

 if ($attr->{MSG_ID}) {
 	  my $value = $self->search_expr($attr->{MSG_ID}, 'INT');
    push @WHERE_RULES, "m.id$value";
  }


 if (defined($attr->{REPLY})) {
 	  my $value = $self->search_expr($attr->{REPLY}, '');
    push @WHERE_RULES, "m.reply$value";
  }

 # Show groups
 if ($attr->{GIDS}) {
   push @WHERE_RULES, "u.gid IN ($attr->{GIDS})"; 
  }
 elsif ($attr->{GID}) {
   push @WHERE_RULES, "u.gid='$attr->{GID}'"; 
  }
 
 #DIsable
 if ($attr->{UID}) {
   push @WHERE_RULES, "m.uid='$attr->{UID}'"; 
 }

 #DIsable
 if ($attr->{STATE}) {
   my $value = $self->search_expr($attr->{STATE}, 'INT');
   push @WHERE_RULES, "m.state$value"; 
  }

 if ($attr->{ID}) {
   my $value = $self->search_expr($attr->{ID}, 'INT');
   push @WHERE_RULES, "mr.id$value"; 
  }
 

 $WHERE = ($#WHERE_RULES > -1) ? 'WHERE ' . join(' and ', @WHERE_RULES)  : '';

  $self->query($db,   "SELECT mr.id,
    mr.datetime,
    mr.text,
    if(mr.aid>0, a.id, u.id),
    mr.status,
    mr.caption,
    INET_NTOA(mr.ip),
    ma.filename,
    ma.content_size,
    ma.id,
    mr.uid,
    SEC_TO_TIME(mr.run_time),
    mr.aid
    FROM (msgs_reply mr)
    LEFT JOIN users u ON (mr.uid=u.uid)
    LEFT JOIN admins a ON (mr.aid=a.aid)
    LEFT JOIN msgs_attachments ma ON (mr.id=ma.message_id and ma.message_type=1 )
    WHERE main_msg='$attr->{MSG_ID}'
    GROUP BY mr.id 
    ORDER BY datetime ASC;");
    #LIMIT $PG, $PAGE_ROWS    ;");

 
 return $self->{list};
}


#**********************************************************
# Reply ADD
#**********************************************************
sub message_reply_add {
	my $self = shift;
	my ($attr) = @_;
  
  %DATA = $self->get_data($attr, { default => \%DATA }); 

  $self->query($db, "insert into msgs_reply (main_msg,
   caption,
   text,
   datetime,
   ip,
   aid,
   status,
   uid,
   run_time
   )
    values ('$DATA{ID}', '$DATA{REPLY_SUBJECT}', '$DATA{REPLY_TEXT}',  now(),
        INET_ATON('$DATA{IP}'), 
        '$DATA{AID}',
        '$DATA{STATE}',
        '$DATA{UID}', '$DATA{RUN_TIME}'
    );", 'do');
 
  
  $self->{REPLY_ID} = $self->{INSERT_ID};

  return $self;	
}

#**********************************************************
#
#**********************************************************
sub attachment_add () {
  my $self = shift;
  my ($attr) = @_;

 $self->query($db,  "INSERT INTO msgs_attachments ".
        " (message_id, filename, content_type, content_size, content, ".
        " create_time, create_by, change_time, change_by, message_type) " .
        " VALUES ".
        " ('$attr->{MSG_ID}', '$attr->{FILENAME}', '$attr->{CONTENT_TYPE}', '$attr->{FILESIZE}', ?, ".
        " current_timestamp, '$attr->{UID}', current_timestamp, '0', '$attr->{MESSAGE_TYPE}')", 
        'do', { Bind => [ $attr->{CONTENT}  ] } );
        
        

  return $self;
}


#**********************************************************
#
#**********************************************************
sub attachment_info () {
  my $self = shift;
  my ($attr) = @_;

  my $WHERE  ='';
  
  if ($attr->{MSG_ID}) {
    $WHERE = "message_id='$attr->{MSG_ID}' and message_type='0'";
   }
  elsif ($attr->{REPLY_ID}) {
    $WHERE = "message_id='$attr->{REPLY_ID}' and message_type='1'";
   }
  elsif ($attr->{ID}) {
  	$WHERE = "id='$attr->{ID}'";
   }

  if ($attr->{UID}) {
  	$WHERE .= " and (create_by='$attr->{UID}' or create_by='0')";
   }

 $self->query($db,  "SELECT id, filename, 
    content_type, 
    content_size,
    content
   FROM  msgs_attachments 
   WHERE $WHERE" );

 return $self if ($self->{TOTAL} < 1);

  ($self->{ATTACHMENT_ID},
   $self->{FILENAME}, 
   $self->{CONTENT_TYPE},
   $self->{FILESIZE},
   $self->{CONTENT}
  )= @{ $self->{list}->[0] };


  return $self;
}


#**********************************************************
# fees
#**********************************************************
sub messages_reports {
  my $self = shift;
  my ($attr) = @_;

 $SORT = ($attr->{SORT}) ? $attr->{SORT} : 1;
 $DESC = ($attr->{DESC}) ? $attr->{DESC} : '';
 my $PG   = ($attr->{PG}) ? $attr->{PG} : 0;
 my $PAGE_ROWS = ($attr->{PAGE_ROWS}) ? $attr->{PAGE_ROWS} : 100;

 $self->{SEARCH_FIELDS} = '';
 $self->{SEARCH_FIELDS_COUNT}=0;
 
 undef @WHERE_RULES;

 # Start letter 
 if ($attr->{FIRST_LETTER}) {
    push @WHERE_RULES, "u.id LIKE '$attr->{FIRST_LETTER}%'";
  }
 elsif ($attr->{LOGIN}) {
    push @WHERE_RULES, "u.id='$attr->{LOGIN}'";
  }
 # Login expresion
 elsif ($attr->{LOGIN_EXPR}) {
    $attr->{LOGIN_EXPR} =~ s/\*/\%/ig;
    push @WHERE_RULES, "u.id LIKE '$attr->{LOGIN_EXPR}'";
  }
 

 if ($attr->{STATUS}) {
    push @WHERE_RULES, @{ $self->search_expr($attr->{STATE}, 'INT', 'm.status') };
  }

 if ($attr->{UID}) {
   push @WHERE_RULES, @{ $self->search_expr($attr->{UID}, 'INT', 'm.uid') };
  }


 my $date='date_format(m.date, \'%Y-%m-%d\')';

 if($attr->{TYPE}) {
   if($attr->{TYPE} eq 'ADMINS') {
     $date = 'a.id';
    }
   elsif ($attr->{TYPE} eq 'USER') {
 	   $date = 'u.id';
    }
   #elsif ($attr->{TYPE} eq 'DATE') { 
   #  $date = "date_format(m.date, '%Y-%m-%d')";
   # }
  }

 # Show groups
 if ($attr->{GIDS}) {
   push @WHERE_RULES, "u.gid IN ($attr->{GIDS})"; 
  }
 elsif ($attr->{GID}) {
   push @WHERE_RULES, "u.gid='$attr->{GID}'"; 
  }


 if ($attr->{DATE}) {
    push @WHERE_RULES, "date_format(m.date, '%Y-%m-%d')='$attr->{DATE}'";
    $date = "date_format(m.date, '%Y-%m-%d')";
  }
 elsif ($attr->{INTERVAL}) {
 	 my ($from, $to)=split(/\//, $attr->{INTERVAL}, 2);
   push @WHERE_RULES, "date_format(m.date, '%Y-%m-%d')>='$from' and date_format(m.date, '%Y-%m-%d')<='$to'";
  }
 elsif (defined($attr->{MONTH})) {
 	 push @WHERE_RULES, "date_format(m.date, '%Y-%m')='$attr->{MONTH}'";
   $date = "date_format(m.date, '%Y-%m-%d')";
  } 
 else {
 	 $date = "date_format(m.date, '%Y-%m')";
  }
 
 $WHERE = ($#WHERE_RULES > -1) ?  "WHERE " . join(' and ', @WHERE_RULES) : '';

 $self->query($db, "SELECT $date, 
   sum(if (m.state=0, 1, 0)),
   sum(if (m.state=1, 1, 0)),
   sum(if (m.state=2, 1, 0)),
   count(*),
   SEC_TO_TIME(sum(mr.run_time)),
   m.uid
   FROM msgs_messages m
  LEFT JOIN  users u ON (m.uid=u.uid)
  LEFT JOIN  admins a ON (m.aid=a.aid)
  LEFT JOIN  msgs_reply mr ON (m.id=mr.main_msg)
  $WHERE
  GROUP BY 1
  ORDER BY $SORT $DESC ; ");
#  LIMIT $PG, $PAGE_ROWS;");


  my $list = $self->{list};

  if ($self->{TOTAL} > 0 || $PG > 0) {
    $self->query($db, "SELECT count(DISTINCT m.id),
      sum(if (m.state=0, 1, 0)),
      sum(if (m.state=1, 1, 0)),
      sum(if (m.state=2, 1, 0)),
      SEC_TO_TIME(sum(mr.run_time)),
      sum(if(m.admin_read = '0000-00-00 00:00:00', 1, 0))
     FROM msgs_messages m
     LEFT JOIN  msgs_reply mr ON (m.id=mr.main_msg)
    $WHERE;");

    ($self->{TOTAL}, 
     $self->{OPEN}, 
     $self->{UNMAKED}, 
     $self->{MAKED},
     $self->{RUN_TIME},
     $self->{IN_WORK}) = @{ $self->{list}->[0] };
   }

  return $list;
}

1


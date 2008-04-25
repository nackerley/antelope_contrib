
#
#output is log format standard: IMS1.0:short
#
#

# future development plans: more flexible
# subsetting should be allowed;

#
# originally J.Eakins 6/1999
# mods by C.Geddes 12/1999
# re-written after format change
#  J.Eakins 2/2007 - 4/2007
# mods for file naming 
#  J.Eakins 1/2008 
# add back in an indicator for prefor
#  J.Eakins 4/2008
# 

require "getopts.pl" ;
use Datascope;
use File::Path;

use strict 'vars' ;
# debug
#use diagnostics;

our ($opt_d, $opt_f, $opt_t, $opt_s, $opt_e, $opt_l, $opt_p, $opt_m, $opt_v, $opt_V, $opt_y);

our ($sub1, $sub2, $start, $end, $cmd) ; 
our ($database, $filename ) ;
our (@db, @dbevent_b, @dborigin_b, @dbj);
our (@dborigin_g, @dbevent_g);
our (@dbarrival, @dbevent, @dborigin, @dbassoc, @dborigerr);
our (@dbsnetsta, @dbschanloc, @dbnetmag, @dbstamag );
our (@trackdb, @dmcbull);

our ($bull, $bulls, $dmcfile);

our ($t, $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);
our ($blank, $value, $agency, $auth) ;
our ($evtype, $emap, $etype, %emap); 
our ($nrecs, $nevents, $event, $origin, $nevents_total) ;
our ($mindelta, $maxdelta, $orid, $ortime, $oYR, $oMO, $oDY, $ohour, $omin, $oms, $omsec);
our ($startyr, $startmo, $startdy);
our ($artime, $arrtime_ms, $atime, $mintime, $maxtime, $arid, $lddate);
our ($smajax, $sminax, $strike, $sdepth, $ndef, $stime, $sdobs, $lat, $lon, $fixed);
our ($match_origerr_auth, $tasdef, $fm, $pickinfo);
our ($maginfo, $magtype, $magnitude, $hashname);
our ($sta, $chan, $filtype, $deltime, $net, $loc, $dist, $evaz, $phase, $tres, $azim);
our ($azres, $slodef, $arrtimesb, $arrtime, $slow, $sres, $snr, $amp, $pre);
our ($cnt_origin, $gregion, $grn, $srn, $otime, $depth, $assoc, $delta) ;
our ($evid, $dtype, $alg, $prefauth, $per);
our ($prefix, $suffix) ;

our ($prefor);

our ($Pf, $auth_reject, $mysubset, $IMSdir) ;


  if ( ! &Getopts('d:f:t:s:e:l:p:mvVy') || @ARGV < 1 || @ARGV > 1) { 
	&usage;
  }

  $database	=  $ARGV[0];
  print  STDERR "\ndatabase is: $database\n" if ($opt_v || $opt_V) ;
  print  STDERR "\nCurrent time:\n " if ($opt_v || $opt_V) ;
  $t = time() ;
  ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($t) ; 
  printf  STDERR "%s UTC\n", &strydtime($t) if ($opt_v || $opt_V) ;  
  printf  STDERR " %2d/%02d/%04d (%03d) %2d:%02d:%02d.000 %s %s\n\n", $mon+1, $mday, $year+1900, $yday+1, $hour, $min, $sec, $ENV{'TZ'}, $isdst ? "Daylight Savings Time" : "Standard Time" if ($opt_v || $opt_V);

  printf  STDERR "Starting $0 at %s UTC\n", &strydtime($t) ;

# get variables set up with getopts
   if ($opt_s) {
	$sub1	= "origin.time";
	$start	= is_epoch_string($opt_s) ;
	$cmd	= "$sub1>='$start'";
   }

   if ($opt_e) {
	$sub1	= "origin.time";
	$end	= is_epoch_string($opt_e) ;
	$cmd	= "$sub1>='$start'&&$sub1<'$end'" if $opt_s;
	$cmd	= "$sub1<'$end'" if !$opt_s;
   } 

   print STDERR "Subset command is: $cmd\n" if ($opt_V);

   if ($opt_t) {
	$sub2	= "origin.lddate";  
	$lddate	= str2epoch ($opt_t) ;	
        print STDERR "Subsetting based on origin.lddate...\n" if ($opt_V);
	print STDERR "... subsetting for all events reviewed after:", epoch2str($opt_t), "\n"  if ($opt_V);
	if (!$cmd) {
            $cmd	= "$sub2>='$lddate'";
	} else { 
            $cmd	= "$cmd && $sub2>='$lddate' ";
	} 
        print STDERR "\nFull database subset: dbsubset $database $cmd \n" if ($opt_v || $opt_V);
   }

   
#
# untested filter option...
# In css3.0 arrival table, there is no way to track the filter used to make the pick.
#

   if ($opt_f) {
	$filtype = $opt_f ;
   } else {
   	$filtype	= " ";
   }

   if ($opt_p) {
	$Pf = $opt_p ;
   } else {
	$Pf = "db2ims" ;
   }

# get information from Pf file

   $agency	= pfget($Pf, 'agency') ;
   $auth_reject	= pfget($Pf, 'auth_reject') ;
   $match_origerr_auth = pfget($Pf, 'match_origerr_auth');
   $IMSdir	= pfget($Pf, 'ims_dir') ;

#
# open up database and lookup tables
#
   @db 		= dbopen ( $database, "r") ; 
   @dborigin	= dblookup(@db,"","origin","","") ;
   @dbassoc	= dblookup(@db,"","assoc","","") ;
   @dbarrival	= dblookup(@db,"","arrival","","") ;
   @dborigerr  	= dblookup(@db,"","origerr","","") ;
   @dbevent	= dblookup(@db,"","event","","") ;
   @dbnetmag	= dblookup(@db,"","netmag","","")  if ($opt_m);
   @dbstamag	= dblookup(@db,"","stamag","","")  if ($opt_m);
   @dbsnetsta  	= dblookup(@db,"","snetsta","","") ;
   @dbschanloc 	= dblookup(@db,"","schanloc","","") ;

   if ( !dbquery(@dborigin,"dbRECORD_COUNT") ) {
	print STDERR "No records in origin table.  Exiting.\n";
	exit(1);
   } else {
	print STDERR dbquery(@dborigin,"dbRECORD_COUNT"), " origin records before any subsets. \n" if ( $opt_V ) ;
   }

#
# take only reviewed origins
#

   if ($opt_y) {
      $nrecs	= dbquery (@dborigin,"dbRECORD_COUNT");
      print STDERR $nrecs, " records before subsetting for reviewed origins. \n" if ( $opt_v ) ;
      @dborigin	= dbsubset(@dborigin, "review=='y'") ; 
      $nrecs	= dbquery (@dborigin,"dbRECORD_COUNT");

      if ( !$nrecs ) {
	    print STDERR "No records in origin table after reviewed origin subset.  Exiting.\n";
	    exit(1);
      } else {
      	    print STDERR $nrecs, " records after subsetting for reviewed origins. \n" if ( $opt_v) ;
      }
   }

#
# reject certain origin authors (i.e. those that are automatic solutions)
#

# get list from pf file and construct subset expression, $auth_reject

   print STDERR  "author reject set to: $auth_reject\n" if ($opt_V);
   $mysubset = "auth !~ /" . $auth_reject . "/";
   @dborigin	= dbsubset(@dborigin, $mysubset  );
   $nrecs	= dbquery (@dborigin,"dbRECORD_COUNT");
   if ( !$nrecs ) {
	print STDERR "No records in origin table after author reject subset.  Exiting.\n";
	exit(1);
   } else {
   	print STDERR $nrecs, " records after removing author rejects. \n" if ($opt_v);
   }

#
# Frank's suggestion to deal with problem where automatic solutions 
# from dborigin2orb/orb2dbt get added to database as prefor, but are 
# not reviewed (problem for rt databases)
#
#  

   @dbj		= dbjoin  (@dbevent, @dborigin);
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining event origin. \n" if $opt_v;
   
   @dbj     = dbsubset(@dbj,"prefor == orid");
   @dbevent = dbseparate(@dbj,"event");
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after separating \"y\" prefor events. \n" if $opt_v;
   

#
# subset origin table based on command line arguments (will have to 
#	change the position of this command in the program if
# 	you broaden the subsetting capabilities)...

   @dborigin  	= dbsubset(@dborigin,   "$cmd") if $cmd ; 
   $nrecs	= dbquery (@dborigin,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after subsetting for origin time, author, and possibly lddate. \n" if ($opt_V);

   if (!$nrecs) {
	print STDERR "No records after time subset.  Exiting.\n";
	exit(1);
   }

#
# determine time of first origin to use for filename check
#
# sort it first to get proper time
#

   @dborigin	= dbsort(@dborigin, "origin.time");

   $dborigin[3] = 0 ;
   $ortime = dbgetv(@dborigin, qw(time));
   $startyr = epoch2str($ortime, "%Y");
   $startmo = epoch2str($ortime, "%m");
   $startdy = epoch2str($ortime, "%d");

   if ($opt_l) {
        $filename = "$opt_l";
   } else {
	$filename = "$IMSdir/$startyr\_$startmo\_$startdy\_$agency"."_IMS";
	print STDERR "filename is: $filename.  \n" if ($opt_V) ;
	print STDERR "Now checking for $IMSdir  existance.\n" if ($opt_V);
	if (! -d $IMSdir) {
	  print STDERR "$IMSdir does not exist.  Creating.\n" if ($opt_v || $opt_V);
	  mkpath "$IMSdir" ;
	}
   }


# check to see if filename already exists in save area

   while (-e $filename) {  
        print STDERR "   Duplicate filename. Attempting a fix.\n " if ($opt_V); 

	if (index($filename,".") < 0) {
           print STDERR "   Attempting to change filename from: $filename to: " if ($opt_V); 
           $filename = $filename . ".1";
           print STDERR "  $filename \n" if ($opt_V); 
	} elsif (index($filename,".") >= 1) {
           print STDERR "   Attempting to change filename from: $filename to: " if ($opt_V) ; 
	    $prefix = substr($filename,0,rindex($filename,"."));
	    $suffix = substr($filename,rindex($filename,".")+1);

               if ($suffix =~ /^[0-9]+$/) { #purely an integer
                  $filename = $prefix . "." . ++$suffix;
           	  print STDERR "  $filename \n" if ($opt_V) ; 
               }  else {
                  $filename = $filename . ".1";
           	  print STDERR "  $filename \n" if ($opt_V) ; 
                  print STDERR "Error: filename already exists.\n" if ($opt_V);
                  print STDERR "Modifying output to $filename.\n" if ($opt_V);
               }

	}
   }

# check to see if filename already exists in tracking db
  
   if (-e $opt_d) {
	@trackdb 	= dbopen ( $opt_d, "r") ; 
	@dmcbull	= dblookup(@trackdb,"","dmcbull","","") ;
	$bulls	= dbquery (@dmcbull,"dbRECORD_COUNT");

   # override default $filename or opt_l (-l) filename if opt_d is used 
   #	and a duplicate filename is found in the output db

	for ($bull = 0; $bull<$bulls; $bull++) {
	    $dmcbull[3] = $bull ;
	    $dmcfile	= dbgetv(@dmcbull, qw(dfile) ) ;
	    if ($dmcfile eq $filename) {
		if (index($filename,".") < 0) {
           	    print STDERR "   Attempting to change filename from: $filename to: " if ($opt_V); 
		    $filename = $filename. ".1";
           	    print STDERR "  $filename \n" if ($opt_V); 
	    	} elsif (index($filename,".") >= 1) {
           	    print STDERR "   Attempting to change filename from: $filename to: " if ($opt_V) ; 
	    	    $prefix = substr($filename,0,rindex($filename,"."));
	    	    $suffix = substr($filename,rindex($filename,".")+1);

                    if ($suffix =~ /^[0-9]+$/) { #purely an integer
                  	$filename = $prefix . "." . ++$suffix;
           	  	print STDERR "  $filename \n" if ($opt_V) ; 
                    }  else {
                  	$filename = $filename . ".1";
           	  	print STDERR "  $filename \n" if ($opt_V) ; 
                  	print STDERR "Error: filename already exists.\n" if ($opt_V);
                  	print STDERR "Modifying output to $filename.\n" if ($opt_V);
               	    }

	    	}
	    }

	}

   } 


#
# join in assoc, arrival, and event tables, sort and prepare groups for reporting
#

   @dbj		= dbjoin  (@dbevent, @dborigin);
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining event origin. \n" if $opt_V;

   @dbj		= dbjoin  (@dbj,@dbassoc);
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining event origin assoc. \n" if $opt_V;

   @dbj		= dbjoin  (@dbj,@dbarrival) ;
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining event origin assoc arrival. \n" if $opt_V;

   @dbj		= dbjoin  (@dbj,@dbsnetsta) ;
   @dbj		= dbjoin  (@dbj,@dbschanloc) ;
   @dbj		= dbsubset (@dbj,"chan==fchan") ;
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining event origin assoc arrival snetsta schanloc. \n" if $opt_V;

   @dbj		= dbjoin  (@dbj,@dborigerr,-outer) ;
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after joining origerr \n" if $opt_V;

   if ($opt_m) { 
     if ( dbquery ( @dbnetmag, "dbRECORD_COUNT")) {
	@dbj = dbjoin (@dbj, @dbnetmag, -outer, "orid");
        $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
	print "", dbquery (@dbj, "dbRECORD_COUNT"), " records after joining netmag \n" if ($opt_V);
     }

     if ( dbquery ( @dbstamag, "dbRECORD_COUNT")) {
	@dbj = dbjoin (@dbj, @dbstamag, -outer);
        $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
	print "", dbquery (@dbj, "dbRECORD_COUNT"), " records after joining stamag \n" if ($opt_V);
     }
   }

   @dbj		= dbsort  (@dbj, "origin.time", "origin.auth", "arrival.time");
   $nrecs	= dbquery (@dbj,"dbRECORD_COUNT");
   print STDERR $nrecs, " records after sorting for origin.time, and arrival.time. \n" if $opt_V;

#
# group by event (evid) since I have multiple origins per event. 
#

   @dborigin_g = dbgroup(@dbj, "time", "evid", "orid", "prefor", "auth", "lat", "lon", "depth", "mb", "ms", "ml", "nass", "ndef", "algorithm", "dtype", "etype", "origin.auth", "review", "stime", "sdobs", "smajax", "sminax", "strike", "sdepth");


   @dbevent_g  = dbgroup(@dborigin_g, "evid", "prefor");

   $nevents	= dbquery (@dbevent_g,"dbRECORD_COUNT");
   print STDERR "Number of grouped events is: $nevents	\n" if ($opt_v || $opt_V);

   if ($nevents <= 1 ) {
        print STDERR "No records after grouping.  \n";
        print STDERR "Check for possible dbpath errors.  Exiting.\n";
        exit(1);
   }

#
# Now that the filename is determined, open it.
#
   print STDERR "Bulletin info will be logged to $filename. \n" if ( $opt_v || $opt_V ) ;

   print STDERR "Done with subsets.  Writing to output file: $filename.\n";

   open (LOG, ">$filename");
   printf LOG "DATA_TYPE BULLETIN IMS1.0:short \n" ;
   printf LOG " (IRIS AGENCY=\"$agency\")\n" ;


   for ($event = 0; $event<$nevents; $event++) {
      $dbevent_g[3]	= $event;
      $nevents_total	= $nevents - 1 ;
      print "\nProcessing event#: $event of $nevents_total\n" if ($opt_v || $opt_V);
      ($evid,$prefor)	= dbgetv(@dbevent_g, qw( evid prefor));

#
# setup @$prefor for accepting %$arid
#
      @{$prefor} = () ;
      print " evid    $evid   prefor   $prefor  \n" if $opt_V ;

      @dbevent_b = split(" ",dbgetv(@dbevent_g,"bundle"));

# PRINT EVENT BLOCK HEADER HERE, leave no carriage return so gregion can be filled in later
      printf LOG "\n\nEVENT $evid ";

#
# find event parameters (get all origin information and add to ORIGIN BLOCK)
#
      $cnt_origin = 0;
      $maxdelta = 0.0;
      $mindelta = 180.0;
      $mintime  = 9999999999.999;
      $maxtime  = -9999999999.999;

      for ($origin=$dbevent_b[3]; $origin<$dbevent_b[2]; $origin++) {
	$dbevent_b[3] = $origin;
	@dborigin_b = split(" ",dbgetv(@dbevent_b,"bundle"));

	($orid ) = dbgetv(@dbevent_b, qw (orid) ) ;
	print "       evid     $evid\n" if $opt_V ;
	print "       orid     $orid\n" if $opt_V ;
	print "       prefor   $prefor\n" if $opt_V ;

	# info from origin table

        ($otime, $lat, $lon, $depth, $ndef, $etype, $dtype, $alg) = dbgetv(@dbevent_b, qw ( time lat lon depth ndef etype dtype algorithm ));
	print "       lat      $lat \n" if $opt_V ;
	print "       lon      $lon \n" if $opt_V ;
	printf "      time     %s \n", strtime($otime) if $opt_V;
	print "       alg      $alg \n" if $opt_V ;


        $prefauth	= dbgetv(@dbevent_b, qw ( auth));
        $auth		= dbgetv(@dborigin_b, qw ( origin.auth)); 
	print "   prefauth     $prefauth \n" if $opt_V ;
	print "       auth     $auth \n" if $opt_V ;

	# info from origerr table
        ($stime, $sdobs, $smajax, $sminax, $strike, $sdepth)     = dbgetv(@dbevent_b, qw ( stime sdobs smajax sminax strike sdepth ));

	$gregion = grname($lat,$lon);
	$grn	= grn($lat,$lon);
	$srn	= srn($lat,$lon);


        $cnt_origin++ ;
	$blank = " ";

        for ($assoc=$dborigin_b[3]; $assoc<$dborigin_b[2]; $assoc++) {
           $dbj[3] = $assoc;
           ($delta, $artime)     = dbgetv(@dbj, qw ( assoc.delta arrival.time));
           $mindelta = $delta if ($delta < $mindelta);
           $maxdelta = $delta if ($delta > $maxdelta);
           $mintime  = $artime  if ($artime < $mintime);
           $maxtime  = $artime  if ($artime > $maxtime);
	# put in if orid == prefor check
	# get all info and put into hash for prefor
	   if ( $orid == $prefor ) {	   
# adding chan, net, and deltime for SUB-BLOCK
	      ($sta, $chan, $net, $loc, $deltime, $dist, $evaz, $phase, $tres, $azim, $azres, $slodef) = dbgetv(@dbj, qw ( assoc.sta chan snet loc deltim delta esaz iphase timeres delta azres slodef))  ;


#
# unprogrammed magtype grab
#
#	      ($magtype, $magnitude) = dbgetv(@dbj, qw ( magtype magniutde ));

		# info from arrival table
	      ($atime, $slow, $sres, $snr, $amp, $per, $fm, $arid) = dbgetv(@dbj, qw ( arrival.time arrival.slow delslo snr amp per fm arid )) ;

		printf "      arrival time     %s \n", strtime($atime) if $opt_V;

		$arrtime_ms	= epoch2str($atime, "%s");

		# get percision and rounding correct 
		if ($arrtime_ms == 1000) {
			$arrtime_ms = 999;
		}

		$arrtime	= epoch2str($atime, "%H:%M:%S") . ".$arrtime_ms"; 
		$arrtimesb	= epoch2str($atime, "%Y/%m/%d");

		$azim 		= sprintf "%5.1f", $azim;
		$dist		= sprintf "%6.2f", $delta;

		if ($azres == -999.0) {  
		    $azres = " " ;
		}	

		if ($slow  == -1.0) {  
		    $slow  = " " ;
		}	

		if ($sres == -1.0) {  
		    $sres = " " ;
		}	

		if ($snr == -1.0) {  
		    $snr  = " " ;
		} elsif ($snr >= 999) {
		    print "Truncating SNR\n" if $opt_V  ;
		    $snr = 999.9 ;
		} else {
		    $snr  = sprintf "%5.1f", $snr ;	
		}	

		if ($amp  == -1.0) {  
		    $amp  = " " ;
		} else {	
		    $amp  = sprintf "%9.1f", $amp ;	
		}

		if ($per  == -1.0) {  
		    $per  = " " ;
		} else {	
		    $per  = sprintf "%5.2f", $per ;	
		}

		if ($loc =~ /-/) {
		    $loc = " " ;
		}

		$tasdef	= "___" ;

		if ($fm !~ /-/ ) {
		   $pickinfo	= "m" . substr($fm,0,1) . "_";
		} else {
		   $pickinfo	= "m__";	# m is used because we only send reviewed solutions, no auto-picks
		}

		if ($opt_m) {	# uncoded magnitude reporting
		   $maginfo = $magtype . " " . $magnitude ;
		} else {
		   $maginfo = $blank;
		}
	
	# put this information in a hash... using arid as main key

		$hashname = $arid ;

		%$hashname = ();
		%$hashname = (
			sta		=> $sta ,
			chan		=> $chan,
			filtype		=> $filtype,
			deltime		=> $deltime,
			net		=> $net,
			loc		=> $loc,
			dist		=> $dist , 
			evaz		=> $evaz , 
			phase		=> $phase ,
			tres		=> $tres, 
			azim		=> $azim ,
			azres		=> $azres ,
			slodef		=> $slodef ,
			magtype		=> $magtype ,
			magnitude 	=> $magnitude ,
			arrtimesb	=> $arrtimesb ,
			arrtime		=> $arrtime ,
			slow		=> $slow ,
			sres		=> $sres ,
			snr		=> $snr ,
			amp		=> $amp ,
			per		=> $pre ,
			fm		=> $fm , 
			pickinfo	=> $pickinfo, 
			arid		=> $arid  
		);
		
		push(@$prefor, $arid) ;

	   } # end of orid == prefor

        } # end of loop over each assoc


# PRINT region for EVENT BLOCK DATA and ORIGIN BLOCK HEADER 
	if ($cnt_origin == 1) {
	    print LOG "$gregion\n";
# ORIGIN BLOCK (HEADER)
	printf LOG "%3s%s%7s%s%8s%s%3s%s%1s%s%1s%s", $blank,"Date",$blank,"Time",$blank,"Err",$blank, "RMS", $blank,"Latitude", $blank,"Longitude";
	printf LOG "%2s%s%2s%s%2s%s%1s%s%3s%s%1s%s", $blank,"Smaj",$blank,"Smin",$blank,"Az",$blank,"Depth",$blank,"Err";
	printf LOG "%s%1s%s%1s%s%2s%s%2s%s%1s%s%3s%s%6s%s\n", "Ndef",$blank,"Nsta",$blank,"Gap",$blank,"mdist",$blank,"Mdist", $blank,"Qual",$blank,"Author",$blank,"OrigId";
	}	 

# PRINT REMAINDER of ORIGIN BLOCK DATA 
	$oYR		= epoch2str($otime,"%Y");
	$oMO		= epoch2str($otime,"%m");
	$oDY		= epoch2str($otime,"%d");
	$ohour		= epoch2str($otime, "%H");
	$omin		= epoch2str($otime, "%M");
	$oms 		= epoch2str($otime, "%S");
	$omsec		= epoch2str($otime, "%s");

	$omsec		= $omsec/10 ;
	$omsec		= sprintf "%2d", $omsec ;

	if ($omsec < 10) {
	    $omsec	= "0" . chop($omsec) ;	
	}

	$fixed = " ";

	if ($dtype =~/g/) { 
	    $fixed = "f"; 
	} else {
	    $fixed = $blank;
	}

	if ($auth !~ /$match_origerr_auth.*/) {
          $stime = $blank ;
	  $sdobs = $blank;  
          $smajax = $blank;
	  $sminax = $blank; 
	  $strike = $blank; 
	  $sdepth = $blank; 
	} else {
	  $strike = sprintf "%3d", $strike;
	  $sdepth = sprintf "%3d", $sdepth;
	}

	if ($ndef == -1) {
		$ndef = $blank ;
	} elsif ($ndef == 0) {
		$ndef = $blank ;
	} 

	$auth = &convert_auth; 
# take out marking of prefor
#	if ( $orid == $prefor ) {
#	    $auth = $auth . "*" ;
#	}

	$etype = &map_etype;
	

        printf "%4s/%2s/%2s %2s:%2s:%s.%s%1s",  $oYR, $oMO, $oDY, $ohour, $omin, $oms, $omsec, $blank if ($opt_v||$opt_V) ;
        printf " %5.2f %5.2f",  $stime, $sdobs  if ($opt_v||$opt_V) ; 
        printf " %8.4f %9.4f%1s %4.1f %5.1f %3s",  $lat, $lon, $fixed, $smajax, $sminax, $strike if ($opt_v||$opt_V); 
        printf " %5.1f%1s %4.1f %4s %4s %3s", $depth, $blank, $sdepth, $ndef, $blank, $blank if ($opt_v||$opt_V); 
        printf " %6.2f %6.2f %1s %1s %2s %9s %8s\n", $mindelta, $maxdelta, $blank, $blank, $etype, $auth, $orid if ($opt_v||$opt_V); 
# ORIGIN BLOCK (DATA)
        printf LOG "%4s/%2s/%2s %2s:%2s:%s.%s%1s",  $oYR, $oMO, $oDY, $ohour, $omin, $oms, $omsec, $blank;

	if ($auth =~ /$match_origerr_auth.*/) {
            printf LOG " %5.2f %5.2f",  $stime, $sdobs ; 
            printf LOG " %8.4f %9.4f%1s ", $lat, $lon, $fixed ;
	    printf LOG "%4.1f %5.1f %3s", $smajax, $sminax, $strike ; 
            printf LOG " %5.1f%1s %4.1f %4s %4s %3s", $depth, $blank, $sdepth, $ndef, $blank, $blank; 
	} else {
            printf LOG " %5s %5s",  $stime, $sdobs ; 
            printf LOG " %8.4f %9.4f%1s ", $lat, $lon, $fixed ;
	    printf LOG "%4s %5s %3s", $smajax, $sminax, $strike ;
            printf LOG " %5.1f%1s %4s %4s %4s %3s", $depth, $blank, $sdepth, $ndef, $blank, $blank; 
	}
        printf LOG " %6.2f %6.2f %1s %1s %2s %9s %8s\n", $mindelta, $maxdelta, $blank, $blank, $etype, $auth, $orid ; 
	
	# Latest officially sanctioned way to determine origin supremacy 
	if ($orid == $prefor) { 
	    printf LOG " %s \n", "(#PRIME)" ; 
	}

      } # end of loop over each origin.  Should have prefor information by now


# In theory, a magnitude block should go here... but I am not coding it for now

# instead of going through bundles, go through prefor hashes

#	print "Printing PHASE BLOCK HEADER\n";
	printf LOG "\n%s%5s%s%2s%s%1s%s%8s%s%6s%s", "Sta",$blank,"Dist",$blank,"EvAZ",$blank,"Phase",$blank,"Time",$blank,"TRes";
	printf LOG "%2s%s%1s%s%3s%s%3s%s%1s%s%3s", $blank,"Azim",$blank,"Azres",$blank,"Slow",$blank,"Sres",$blank,"Def",$blank;
	printf LOG "%s%7s%s%3s%s%1s%s%1s%s%4s%s\n", "SNR",$blank,"Amp",$blank,"Per",$blank,"Qual",$blank,"Magnitude", $blank,"ArrID";

#	print "Printing PHASE BLOCK DATA\n";
	foreach $value (@$prefor) {
		printf LOG "%-5s %6.2f %5.1f %-8s %12s %5.1f %5.1f %5s %6s %6s %3s %5s %9s %5s %3s %9s  %8s \n",  $$value{sta}, $$value{dist}, $$value{evaz}, $$value{phase}, $$value{arrtime}, $$value{tres}, $$value{azim}, $$value{azres}, $$value{slow}, $$value{sres}, $$value{tasdef}, $$value{snr}, $$value{amp}, $$value{per}, $$value{pickinfo}, $$value{maginfo}, $$value{arid}; 
	}
# PHASE INFO SUB-BLOCK
#	print "Printing PHASE SUB-BLOCK HEADER \n";
	printf LOG "\n%s%6s%s%1s%s%1s%s%1s%s%1s%s", "Net",$blank,"Chan",$blank,"F",$blank,"Low_F",$blank,"HighF",$blank,"AuthPhas";
	printf LOG "%4s%s%5s%s%1s%s%1s%s%1s%s%2s", $blank,"Date",$blank,"eTime",$blank,"wTime",$blank,"eAzim",$blank,"wAzim",$blank;
	printf LOG "%s%1s%s%6s%s%2s%s%1s%s%2s%s%4s%s\n", "eSlow",$blank,"wSlow",$blank,"eAmp",$blank,"ePer",$blank,"eMag",$blank,"Author",$blank,"ArrID";
	foreach $value (@$prefor) {
		printf LOG "%-9s %3s %1s %5s %5s %-8s %10s %6.3f %5s %5s %5s %6s %5s %9s %5s %3s %8s %8s\n",  $$value{net}, $$value{chan}, $$value{filtype}, $blank, $blank, $$value{phase}, $$value{arrtimesb}, $$value{deltime}, $blank, $blank, $blank, $blank, $blank, $blank, $blank, $blank, $agency, $$value{arid}; 
		# print the totally moronic comment lines that make reading this file impossible
		if (!$$value{loc}) { 
		    printf LOG " %s%s%s  \n", "(IRIS FDSNNETWORKCODE=\"", $$value{net}, "\")" ; 
		} else {
		    printf LOG " %s%s%s%2s%s  \n", "(IRIS FDSNNETWORKCODE=\"", $$value{net}, "\" FDSNLOCATIONID=\"", $$value{loc}, "\")" ;
		}

	}

   } #end of loop over each event 

#print LOG "End of run\n";

dbclose @db;
close(LOG);

sub convert_auth {

	if ($auth=~/cit.*/) {
		$auth = "SCEDC";
	} elsif ($auth=~/ISC/) {
		$auth = "ISC" ;
	} elsif ($auth=~/QED_weekly/) {
		$auth = "PDE-W" ;
	} elsif ($auth=~/PDE/) {
		$auth = "PDE" ;
	} elsif ($auth=~/QED/) {
		$auth = "PDE-Q" ;
	} elsif ($auth=~/UNR.*/) {
		$auth = "UNR";
	} elsif ($auth=~/NCEDC.*/) {
		$auth = "NCEDC";
	} elsif ($auth=~/ANFR.*/) {
		$auth = "ANFR";
	} elsif ($auth=~/ANF:.*/) {
		$auth = "ANF";
	} elsif ($auth=~/PNSN.*/) {
		$auth = "PNSN";
	} elsif ($auth=~/MTECH.*/) {
		$auth = "MTECH";
	} elsif ($auth=~/UTAH.*/) {
		$auth = "UUSS";
	} elsif ($auth=~/UCSD.*/) {
		$auth = "ANZA";
	} else {
		$auth = "UNKNWN";
	}

	print STDERR "converted auth is: $auth\n" if $opt_V;
	return $auth; 
}


sub map_etype {
	
	%emap = (
	         L => "ke",
		 l => "ke",
		le => "ke",
		LE => "ke",
		 U => "uk",
		UK => "uk",
		 u => "uk",
		uk => "uk",
		 q => "km",
		 Q => "km",
		qb => "km",
		QB => "km",
		 T => "ke",
		 t => "ke",
		ts => "ke",
		TS => "ke",
		 R => "ke",
		 r => "ke",
		re => "ke",
		RE => "ke",
		 N => "kn",
		 n => "kn",
		nt => "kn",
		NT => "kn",
		 o => " ",
		 "-" => " "
	);

	$evtype = $emap{$etype}; 
	print STDERR "etype is: $evtype\n" if $opt_V;
	return $evtype; 
	
}



sub usage{
	print STDERR <<ENDIT ;
\nUSAGE: \t$0 [-v] [-V] [-y] [-m] [-s start_origin.time] [-e end_origin.time] [-p pf] [-l logfile] [-d dbops] database 

ENDIT
exit;
}

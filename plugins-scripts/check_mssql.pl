#!/usr/bin/perl -w

#
# Copyright 2003 Roy Sigurd Karlsbakk
#
# Requires freetds and DBD::Sybase
# http://www.freetds.org
# http://www.mbay.net/~mpeppler/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA
#
# Report bugs to: help@nagios-plugins.org
#
#
###########################################
# Additions/changes  -- https://github.com/ljl-geek/
# 1) update lib to current plugins location
# 2) update help to show correct option for hostname (-H not -s)
# 3) put full program name, including extension
# 4) add checking for numeric value
# 5) add checking against warning and critical thresholds < & >

use DBI;
use DBD::Sybase;
use Getopt::Long;
use lib "/usr/lib64/nagios/plugins";
use utils qw($TIMEOUT %ERRORS &print_revision &support);
use strict;

my $PROGNAME = "check_mssql.pl";

my (
        $server,$database,$username,$password,$query,$help,$verbose,$timeout,
        $dbh,$sth,$row,
        $s,$opt_V,$regex,$number,$warnl,$critl,$warng,$critg
);
my $exitcode = $ERRORS{'OK'};

process_arguments();

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
     print ("SQL UNKNOWN: ERROR connection $server (alarm timeout)\n");
     exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

unless ($dbh = DBI->connect("dbi:Sybase:server=".uc($server), "$username", "$password")) {
        printf "SQL CRITICAL: Can't connect to mssql server $DBI::errstr\n";
        exit($ERRORS{'CRITICAL'});
}

if (defined $database) {  # otherwise use default database
        unless ($dbh->do("use $database")) {
                printf ("SQL CRITICAL: Can't 'use $database': $dbh->errstr");
                exit($ERRORS{'CRITICAL'});
        }
}
$sth = $dbh->prepare($query);
unless ($sth->execute()) {
        printf("SQL CRITICAL: Error in query: $dbh->errstr\n");
        exit($ERRORS{'CRITICAL'});
}

$row = join(";",$sth->fetchrow_array);

print "Result = $row\n" if $verbose;
$sth->finish;
$dbh->disconnect;

alarm(0);
if (defined $regex) {
        if ($row =~ /$regex/) {
                printf "SQL CRITICAL: - $row | $row\n";
                exit $ERRORS{'CRITICAL'};
        }else{
                print "SQL OK: $row | $row\n";
                exit $ERRORS{'OK'};
        }
}

if (defined $number) {
        if ($row == $number) {
                printf "SQL CRITICAL: - $row = $number | $row\n";
                exit $ERRORS{'CRITICAL'};
        }else{
                print "SQL OK: $row != $number| $row\n";
                exit $ERRORS{'OK'};
        }
}

if ((defined $critl) || (defined $critg) || (defined $warnl) || (defined $warng)
) {
        if ($row !~  /\d+/) {
                print ("SQL UNKNOWN: ERROR Result is not numeric, but you have numeric thresholds\n");
                exit $ERRORS{"UNKNOWN"};
        } elsif ((defined $critl) && ($row < $critl)) {
                printf "SQL CRITICAL: - $row < $critl | $row\n";
                exit $ERRORS{'CRITICAL'};
        } elsif ((defined $critg) && ($row > $critg)) {
                printf "SQL CRITICAL: - $row > $critg | $row\n";
                exit $ERRORS{'CRITICAL'};
        } elsif ((defined $warnl) && ($row < $warnl)) {
                printf "SQL WARNING: - $row < $warnl | $row\n";
                exit $ERRORS{'WARNING'};
        } elsif ((defined $warng) && ($row > $warng)) {
                printf "SQL WARNING: - $row > $warng | $row\n";
                exit $ERRORS{'WARNING'};
        }
}

print "SQL OK: $row | $row\n";
exit $ERRORS{'OK'};

##################################################

sub syntax {
        $s = shift or $s = 'Unknown';
        printf("Error: ($s)\n") unless ($help);
        printf("Runs a query against a MS-SQL server or Sybase server and returns the first row\n");
        printf("Returns an error if no responses are running. Row is passed to perfdata in\n");
        printf("semicolon delimited format\n");
        printf("A simple sql statement like \"select getdate()\" verifies server responsiveness\n\n");
        printf("Syntax: %s -H <server> -d <database> -u <username> -p <password> -q <query> [-v]\n", $PROGNAME);
        printf("  --database -d         Database name\n");
        printf("  --Hostname -H         Server name\n");
        printf("  --username -u         Username\n");
        printf("  --password -p         Password\n");
        printf("  --query -q            SQL query to run\n");
        printf("  --timeout -t          Plugin timeout (default:$TIMEOUT)\n");
        printf("  --regex -r            regex against SQL response(CRIT if MATCH)\n");
        printf("  --number -n           numeric value against SQL response (CRIT if == number)\n");
        printf("  --warnlow -w          warning threshold (less than warn)\n");
        printf("  --warnhigh -W         warning threshold (greater than warn)\n");
        printf("  --critlow -c          critical threshold (less than critical)\n");
        printf("  --crithigh -C         critical threshold (greater than critical)\n");
        printf("  --verbose -v          verbose\n");
        printf("\nThe SQL response is concatenated into a string with a \";\" demarkation\n\n");
        exit($ERRORS{'UNKNOWN'});
}

sub process_arguments {
        Getopt::Long::Configure('bundling');
        my $status = GetOptions
                ("p=s" => \$password, "password=s" => \$password,
                 "u=s" => \$username, "username=s" => \$username,
                 "H=s" => \$server, "Hostname=s"    => \$server,
                 "d=s" => \$database, "database=s" => \$database,
                 "q=s" => \$query, "query=s" => \$query,
                 "t=i" => \$timeout, "timeout=i" => \$timeout,
                 "r=s" => \$regex, "regex=s" => \$regex,
                 "n=s" => \$number, "number=s" => \$number,
                 "w=s" => \$warnl, "warnlow=s" => \$warnl,
                 "c=s" => \$critl, "critlow=s" => \$critl,
                 "W=s" => \$warng, "warnhigh=s" => \$warng,
                 "C=s" => \$critg, "crithigh=s" => \$critg,
                 "h" => \$help, "help" => \$help,
                 "v" => \$verbose, "verbose" => \$verbose,
                 "V" => \$opt_V, "version" => \$opt_V);

        if (defined $opt_V) {
                print_revision($PROGNAME,'@NP_VERSION@');
                exit $ERRORS{'OK'};
        }

        syntax("Help:") if ($help);
        syntax("Missing username") unless (defined($username));
        syntax("Missing password") unless (defined($password));
        syntax("Missing server") unless (defined($server));
        syntax("Missing query string") unless (defined($query));
        $timeout = $TIMEOUT unless (defined($timeout));

        return;

}

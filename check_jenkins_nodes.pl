#!/usr/bin/perl
#
use lib '/usr/lib/nagios/plugins';
use utils qw(%ERRORS $TIMEOUT);

use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use Getopt::Std;

use Data::Dumper;
# TODO: get error code & output correct
# TODO: error if warning > critical

sub main {

    my %options=();
    getopts("c:hs:p:u:vw:", \%options);

    if($options{'h'})
    {
        usage();
        exit $ERRORS{'UNKNOWN'};
    }

    # TODO: error check for -c, -s ,-w

    my $ciHost   = $options{'s'};
    my $username = $options{'u'};
    my $password = $options{'p'};
    my $warning  = $options{'w'};
    my $critical = $options{'c'};

    my $nodeStatusUrl = $ciHost . "/computer/api/json";

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $nodeStatusUrl);

    if ($username)
    {
        $req->authorization_basic($username, $password);
    }

    my $res = $ua->request($req);

    # if we have a HTTP 200 OK response
    if ($res->is_success)
    {
        my $json = new JSON;
        my $obj = $json->decode($res->content);

        my @offline;
        my $totalNodes = 0;

        for my $computer (@{$obj->{'computer'} or []})
        {
            ++$totalNodes;
            if($computer->{'offline'} eq 'true')
            {
                push(@offline, {
                    'displayName' => $computer->{'displayName'},
                    'offlineCauseReason' => $computer->{'offlineCauseReason'}
                });
            }
        }

        if (my $offlineNodes = scalar(@offline))
        {
            my $criticalThreshold = $critical;
            if ($critical =~ s/\%$//)
            {
                $criticalThreshold = $critical/100 * $totalNodes;
            }

            if ($offlineNodes >= $criticalThreshold)
            {
                print "offlineNodes = $offlineNodes/$totalNodes, criticalThreshold=$criticalThreshold\n";
                exit $ERRORS{'CRITICAL'};
            }

            my $warningThreshold = $warning;
            if ($warning =~ s/\%$//)
            {
                $warningThreshold = $warning/100 * $totalNodes;
            }

            if ($offlineNodes >= $warningThreshold)
            {
                print "offlineNodes = $offlineNodes/$totalNodes, warningThreshold=$warningThreshold\n";
                exit $ERRORS{'WARNING'};
            }

            exit $ERRORS{'OK'};
        }

    }
    else
    {
        #$retStr = "Failed retrieving node status via API (API status line: $res->{status_line})";
    exit $ERRORS{'UNKNOWN'};
    }


}

sub usage {

    print qq|\nUsage: check_jenkins_nodes.pl -s [jenkins server hostname & path] -w [integer or %] -c [integer or %] [-h this help message] [-u username] [-p password] [-v]\n|;

    # Extended usage information:
    #
    #     -h This help message
    #
    #     -v verbose output
}

main();

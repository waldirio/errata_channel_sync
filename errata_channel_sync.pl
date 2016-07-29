#!/usr/bin/perl
use Frontier::Client;
use warnings;
use Data::Dumper;

############################################################
# Used to merge any packages that are in an original channel 
# that are not in the destination into the destination.
# 
# USAGE: edit the Configuration section below to contain 
#        valid host/user credentials; and two channel names
#        where any packages not in orig channel will be
#        added to the dest channel.
#
#


############################################################
# Configuration 
############################################################

# Satellite host to connect to (domain name) http://$HOST/rpc/api
my $SAT_HOST = 'localhost'; 

# Satellite admin username/password
my $SAT_USER = 'admin';
my $SAT_PASS = 'redhat';

# Channels to compare and merge
# (packages in orig that are not in dest are added to dest)
my $origchannellabel = " rhel-x86_64-server-6";
my $destchannellabel = "waldirio-rhel-x86_64-server-6";

# Debug for API calls (1 to enable, 0 to disable)
my $DEBUG_API = 0;


############################################################
# Helper Functions 
############################################################

# Helper to transform package objects to list of names
sub getNames {
    my ($pkgs) = @_;
    return map { $_->{'name'} . '-' . $_->{'version'}
		 . '-' . $_->{'release'}
		 . '.' . $_->{'arch_label'}
    } @$pkgs;
}

# Helper to transform package objects to list of pkg ids
sub getPkgIDs {
    my ($pkgs) = @_;
    return map { $_->{'id'} } @$pkgs;
}


############################################################
# Main Code to merge channel packages
############################################################

## Setup connection and login to Satellite API
my $client = new Frontier::Client(url => "http://$SAT_HOST/rpc/api", debug=>$DEBUG_API);
my $session = $client->call('auth.login', $SAT_USER, $SAT_PASS );


# Grab list of packages in Original channel
print "\nPulling list of packages in Original channel:' $origchannellabel' ...\n";
my $orig_pkgs = $client->call('channel.software.listAllPackages', $session, $origchannellabel);

# Grab list of packages in Destination channel
print "\nPulling list of packages in Destination channel:' $destchannellabel' ...\n";
my $dest_pkgs = $client->call('channel.software.listAllPackages', $session, $destchannellabel);


#Convert packages lists to array of package names
#my @orig_names = getNames($orig_pkgs);
#my @dest_names = getNames($dest_pkgs);
#print "=======ORIG========\n";
#print "names:@orig_names\n";
#print "=======DEST========\n";
#print "names:@dest_names\n";

# Convert packages list to array of package IDs
my @orig_ids = getPkgIDs($orig_pkgs);
my @dest_ids = getPkgIDs($dest_pkgs);

# Diff the destination (minimal) w/ original (ie. get missing packages)
my %minimal = map {($_, 1)} @dest_ids;
my @missing = grep {!$minimal{$_}} @orig_ids;

# Print list of packages that will be added
#print "missing: @missing\n";


# Abort if no packages are missing, otherwise continue
if($#missing < 1){
    print "\nNo Packages in '$origchannellabel' missing from '$destchannellabel'.\n";
#    goto FINISH;
    goto ERRATA;
} else {
    print "\nNow merging $#missing packages into '$destchannellabel'.\n";
}

# Add missing packages to destination channel
my $result = $client->call('channel.software.addPackages', $session, $destchannellabel, \@missing);

print "done merging; (" . Dumper($result) . ")\n";

ERRATA:
print "\nMerging all Erratas from: '$origchannellabel' to: '$destchannellabel' ..\n";
my $merge_pkgs = $client->call('channel.software.mergeErrata', $session, $origchannellabel, $destchannellabel);

#print "Merge values: $merge_pkgs";
#my @aux = getPkgIDs($merge_pkgs);
#print "Merge values: @aux";

print "\nSyncing Repo: '$destchannellabel' ..\n";
my $aux1 = $client->call('channel.software.syncErrata', $session, $destchannellabel);

## Clean up and exit 

FINISH:

## Close connection to Satellite.
print "\nLogging out...\n";
$client->call('auth.logout', $session);

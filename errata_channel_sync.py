#!/usr/bin/python
import xmlrpclib
import ConfigParser 
import os
import time

############################################################
#
# Configuration Defaults 
# 

CREDS_FILE = 'rhn_api.credentials'
CREDS_PATH = os.path.dirname(os.path.realpath(__file__)) + "/" + CREDS_FILE

# Best to store this as CREDS_FILE in dir w/ this script:
#
# [credentials]
# sat_url = https://<host>/rpc/api
# sat_user = <username>
# sat_pass = <password>

config = ConfigParser.ConfigParser( defaults={
   'sat_url':'https://rhn.redhat.com/rpc/api',
   'sat_user':'<username>',
   'sat_pass':'<password>'
})

############################################################
#
# Load Credentials from file
#
try:
   config.readfp(open(CREDS_PATH))
except IOError:
   config.add_section('credentials')
   pass
finally:
   sat_url  = config.get('credentials','sat_url')
   sat_user = config.get('credentials','sat_user')
   sat_pass = config.get('credentials','sat_pass')

############################################################
#
# helper functions
#

def testBzFixes(erratas,delay=0):
   """Request and Print bugzillaFixes for each `errata`. """   
   for ename in erratas:
      print "== Puling errata " + ename  + " ..."
      rslts = client.errata.bugzilla_fixes(key,ename)
      print str(rslts) + '\n'
      if delay > 0: #and len(erratas) > 1:
         time.sleep(delay)

############################################################
#
# Authenticate and run tests
#

### Authenticate against Server + Get session key
client = xmlrpclib.Server(sat_url, verbose=0)
key = client.auth.login(sat_user, sat_pass)


### Test simple api call (user info)
uinfo = client.user.get_details(key,sat_user)
print "If auth worked then user info is below:"
print str(uinfo) + '\n'


### Test errata.bugzilla_fixes
testBzFixes(['RHSA-2013:0614'])


### Trouble errata 
testBzFixes(['RHEA-2013:1025','RHEA-2013:0880'],2)

### Test NEW Trouble errata
print "Testing NEW errata..."
#/RHEA-2013:1025/, /RHEA-2013:0880/ , /RHBA-2013:0032/ , /RHBA-2011:0755/
testBzFixes(['RHEA-2013:1025','RHEA-2013:0880','RHBA-2013:0032','RHBA-2011:0755'],2)

### Pull all package id for pkg_name, check bugzillaFixes for their errata.

pkg_name  = 'tzdata'
chan_name = 'rhel-x86_64-server-6'

print "== Pulling package list for channel: " + chan_name + " ..."
pkgs = client.channel.software.list_all_packages(key,chan_name)
print "channel " + chan_name + " contains: " + str(len(pkgs)) + " packages."

print "== Filtering out packages for " + pkg_name + " ..."
pkg_matches = list(pkg for pkg in pkgs if pkg['package_name'] == pkg_name)
print "found " + str(len(pkg_matches)) + " matches."
print str(pkg_matches)
# be picky and get list of just IDs (for short display)
tz_ids = map(lambda x:x['package_id'],pkg_matches)
print "package ids:" + str(tz_ids) + '\n'

# Collect bz for each errata, for each id of pkg_name
print "== Pulling errata for " + pkg_name + " IDs ..."
for p in tz_ids:
   # grab errata list for current package id, then bz for each errata
   elist = client.packages.list_providing_errata(key,p)
   for e_id in elist:
      bzl = client.errata.bugzilla_fixes(key,e_id['errata_advisory'])
      print "id-" + str(p) + "[" + e_id['errata_advisory'] + "] " + str(bzl)
      time.sleep(1)
   

# Close API session
client.auth.logout(key)

<?php
$conf['useacl']      = 1;
$conf['openregister']= 0;
$conf['authtype']    = 'authldap';
$conf['allowdebug']  = 1;

/* OpenLDAP config - details: https://www.dokuwiki.org/plugin:authldap:openldap */
#$conf['plugin']['authldap']['server']      = 'localhost';
#$conf['plugin']['authldap']['port']        = 389;
$conf['plugin']['authldap']['server']      = 'ldap://localhost:389';
$conf['plugin']['authldap']['usertree']    = 'ou=People, dc=devkit, dc=cw';
$conf['plugin']['authldap']['grouptree']   = 'ou=Groups, dc=devkit, dc=cw';
$conf['plugin']['authldap']['userfilter']  = '(&(objectClass=posixAccount)(uid=%{user}))';
$conf['plugin']['authldap']['groupfilter'] = '(&(objectClass=posixGroup)(|(memberUid=%{uid})(gidNumber=%{gid})))';

# This is optional but may be required for your server:
$conf['plugin']['authldap']['version']    = 3;

# This enables the use of the STARTTLS command
#$conf['plugin']['authldap']['starttls']   = 1;

# This is optional and is required to be off when using Active Directory:
#$conf['plugin']['authldap']['referrals']  = 0;

# Optional bind user and password if anonymous bind is not allowed
#$conf['plugin']['authldap']['binddn']     = 'cn=admin, dc=my, dc=home';
#$conf['plugin']['authldap']['bindpw']     = 'secret';


# Limit search scope for user and group searches (sub|one|base)
$conf['plugin']['authldap']['userscope']  = 'one';
$conf['plugin']['authldap']['groupscope'] = 'one';

# Optional debugging
#$conf['plugin']['authldap']['debug']      = 1;

#### not available via Config Manager ####
# Mapping can be used to specify where the internal data is coming from.
$conf['plugin']['authldap']['mapping']['name']  = 'cn'; # Name of attribute Active Directory stores it's pretty print user name.
#$conf['plugin']['authldap']['mapping']['grps']  = array('memberof' => '/CN=(.+?),/i'); # Where groups are defined in Active Directory

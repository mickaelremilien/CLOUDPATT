<?php
$conf['useacl']      = 1;
$conf['openregister']= 0;
$conf['authtype']    = 'authldaplocal';
$conf['allowdebug']  = 1;

/* OpenLDAP config - details: https://www.dokuwiki.org/plugin:authldaplocal:openldap */
#$conf['plugin']['authldaplocal']['server']      = 'localhost';
$conf['plugin']['authldaplocal']['port']        = 0;
$conf['plugin']['authldaplocal']['server']      = 'ldap://localhost:389';
$conf['plugin']['authldaplocal']['usertree']    = 'ou=People, dc=devkit, dc=cw';
$conf['plugin']['authldaplocal']['grouptree']   = 'ou=Groups, dc=devkit, dc=cw';
$conf['plugin']['authldaplocal']['userfilter']  = '(&(objectClass=posixAccount)(uid=%{user}))';
$conf['plugin']['authldaplocal']['groupfilter'] = '(&(objectClass=posixGroup)(|(memberUid=%{uid})(gidNumber=%{gid})))';

# This is optional but may be required for your server:
$conf['plugin']['authldaplocal']['version']    = 3;

# This enables the use of the STARTTLS command
#$conf['plugin']['authldaplocal']['starttls']   = 1;

# This is optional and is required to be off when using Active Directory:
#$conf['plugin']['authldaplocal']['referrals']  = 0;

# Optional bind user and password if anonymous bind is not allowed
#$conf['plugin']['authldaplocal']['binddn']     = 'cn=admin, dc=my, dc=home';
#$conf['plugin']['authldaplocal']['bindpw']     = 'secret';


# Limit search scope for user and group searches (sub|one|base)
$conf['plugin']['authldaplocal']['userscope']  = 'one';
$conf['plugin']['authldaplocal']['groupscope'] = 'one';

# Optional debugging
#$conf['plugin']['authldaplocal']['debug']      = 1;

#### not available via Config Manager ####
# Mapping can be used to specify where the internal data is coming from.
#$conf['plugin']['authldaplocal']['mapping']['name']  = 'cn'; # Name of attribute Active Directory stores it's pretty print user name.
#$conf['plugin']['authldaplocal']['mapping']['grps']  = array('memberof' => '/CN=(.+?),/i'); # Where groups are defined in Active Directory

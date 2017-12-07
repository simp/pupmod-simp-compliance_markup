# Incomplete justifications are marked TODO

ssg = {
  "DISA_STIG" => {
    "CentOS" => {
      "7" => {
        "xccdf_org:ssgproject.content_rule_aide_periodic_cron_checking" => {
          "remediation" =>
'''This is not enabled in SIMP by default since it can be an extreme burden on your system depending on your partitioning.

If you wish to enable this, you can use the following Hiera data:

---
aide::enable: true
This is implemented using the native cron Puppet resource and, therefore, is placed into the root crontab directly.

22 4 * * 0 /bin/nice -n 19 /usr/sbin/aide -C''',
        },
        "xccdf_org:ssgproject:content_rule_aide_scan_notification" => {
          "remediation" =>
'''This is not enabled in SIMP by default since it can be an extreme burden on your system depending on your partitioning.

If you wish to enable this, you can add the following Hiera data:
---
aide::enable: false

Add the following to a manifest:
  cron { \'aide_schedule\':
    command  => \'/bin/nice -n 19 /usr/sbin/aide -C | /bin/mail -s "$(hostname) - AIDE Integrity Check" root@localhost\'
    user     => \'root\',
    minute   => $minute,
    hour     => $hour,
    monthday => $monthday,
    month    => $month,
    weekday  => $weekday
  }''',
          "notes" => "We should expose aide::set_schedule command/user so users can easily tweak Hiera data, and add compliant values in compliance data (05 4 * * * root /usr/sbin/aide --check | /bin/mail -s \"$(hostname) - AIDE Integrity Check\" root@localhost)"
        },
        "xccdf_org:ssgproject:content_rule_aide_verify_ext_attributes" => {
          "remediation" =>
'''Set the following in Hiera Data:
aide::aliases:
  - \'R = p+i+l+n+u+g+s+m+c+sha1+sha256\'
  - \'L = p+i+l+n+u+g+acl+xattrs\'
  - \'> = p+i+l+n+u+g+S+acl+xattrs\'
  - \'ALLXTRAHASHES = sha1+sha256\'
  - \'EVERYTHING = R+ALLXTRAHASHES\'
  - \'FIPSR = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha256\'
  - \'NORMAL = FIPSR+sha512\'
  - \'DIR = p+i+n+u+g+acl+xattrs\'
  - \'PERMS = p+i+u+g+acl\'
  - \'LOG = >\'
  - \'LSPP = R\'
  - \'DATAONLY = p+n+u+g+s+acl+selinux+xattrs+sha1+sha256\'''',
        },
        "xccdf_org:ssgproject:content_rule_adie_use_fips_hashes" => {
          "remediation" => 
'''Set the following in Hiera Data:
aide::aliases:
  - \'R = p+i+l+n+u+g+s+m+c+sha1+sha256\'
  - \'L = p+i+l+n+u+g+acl+xattrs\'
  - \'> = p+i+l+n+u+g+S+acl+xattrs\'
  - \'ALLXTRAHASHES = sha1+sha256\'
  - \'EVERYTHING = R+ALLXTRAHASHES\' 
  - \'FIPSR = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha256\'
  - \'NORMAL = FIPSR+sha512\'
  - \'DIR = p+i+n+u+g+acl+xattrs\'
  - \'PERMS = p+i+u+g+acl\'
  - \'LOG = >\'
  - \'LSPP = R\'
  - \'DATAONLY = p+n+u+g+s+acl+selinux+xattrs+sha1+sha256\'''',
        },
        "xccdf_org:ssgproject:content_rule_rpm_verify_permissions" => {
          "remediation" =>
'''Most files have more restrictive permissions than the permissions provided by the RPMs.

Exceptions are noted in the output below.

for f in `rpm -Va | grep \'^.M\' | rev | cut -f1 -d' ' | rev`; do echo -n "RPM: "; rpm -qvlf $f | grep -e "[[:space:]]${f}$"; echo -n "Local: "; ls -ld $f; echo; done

RPM: -rw-r--r--    1 root    root                     9438 Jul 12 09:00 /etc/httpd/conf.d/ssl.conf
Local: -rw-r-----. 1 apache apache 1055 Dec 15 19:02 /etc/httpd/conf.d/ssl.conf

RPM: -rw-r--r--    1 root    root                      473 Jul 27 09:08 /etc/rc.d/rc.local
Local: -rw-------. 1 root root 49 Dec 15 17:30 /etc/rc.d/rc.local

RPM: -rw-r--r--    1 root    root                    20876 Jan 26  2014 /etc/postfix/access
Local: -rw-r-----. 1 root root 20876 Jan 26  2014 /etc/postfix/access

RPM: -rw-r--r--    1 root    root                    11681 Jan 26  2014 /etc/postfix/canonical
Local: -rw-r-----. 1 root root 11681 Jan 26  2014 /etc/postfix/canonical

RPM: -rw-r--r--    1 root    root                     9904 Jan 26  2014 /etc/postfix/generic
Local: -rw-r-----. 1 root root 9904 Jan 26  2014 /etc/postfix/generic

RPM: -rw-r--r--    1 root    root                    21545 Jan 26  2014 /etc/postfix/header_checks
Local: -rw-r-----. 1 root root 21545 Jan 26  2014 /etc/postfix/header_checks

RPM: -rw-r--r--    1 root    root                     6105 Jan 26  2014 /etc/postfix/master.cf
Local: -rw-r-----. 1 root root 6105 Jan 26  2014 /etc/postfix/master.cf

RPM: -rw-r--r--    1 root    root                     6816 Jan 26  2014 /etc/postfix/relocated
Local: -rw-r-----. 1 root root 6816 Jan 26  2014 /etc/postfix/relocated

RPM: -rw-r--r--    1 root    root                    12549 Jan 26  2014 /etc/postfix/transport
Local: -rw-r-----. 1 root root 12549 Jan 26  2014 /etc/postfix/transport

RPM: -rw-r--r--    1 root    root                    12494 Jan 26  2014 /etc/postfix/virtual
Local: -rw-r-----. 1 root root 12494 Jan 26  2014 /etc/postfix/virtual

# There were issues when this was not executable
RPM: -rw-r--r--    1 root    root                    26990 Jan 26  2014 /usr/libexec/postfix/main.cf
Local: -rwxr-xr-x. 1 root root 26990 Jan 26  2014 /usr/libexec/postfix/main.cf

# There were issues when this was not executable
RPM: -rw-r--r--    1 root    root                     6105 Jan 26  2014 /usr/libexec/postfix/master.cf
Local: -rwxr-xr-x. 1 root root 6105 Jan 26  2014 /usr/libexec/postfix/master.cf

# There were issues when this was not executable
RPM: -rw-r--r--    1 root    root                    19366 Jan 26  2014 /usr/libexec/postfix/postfix-files
Local: -rwxr-xr-x. 1 root root 19366 Jan 26  2014 /usr/libexec/postfix/postfix-files

RPM: -rw-r--r--    1 root    root                      253 Nov 22 21:37 /etc/puppetlabs/orchestration-services/conf.d/authorization.conf
Local: -rw-r-----. 1 pe-orchestration-services pe-orchestration-services 2263 Dec 14 20:42 /etc/puppetlabs/orchestration-services/conf.d/authorization.conf

RPM: -rw-r--r--    1 root    root                      388 Nov 22 21:37 /etc/puppetlabs/orchestration-services/conf.d/orchestrator.conf
Local: -rw-r-----. 1 pe-orchestration-services pe-orchestration-services 1344 Dec 14 20:40 /etc/puppetlabs/orchestration-services/conf.d/orchestrator.conf

RPM: -rw-r--r--    1 root    root                      327 Nov 22 21:37 /etc/puppetlabs/orchestration-services/conf.d/pcp-broker.conf
Local: -rw-r-----. 1 pe-orchestration-services pe-orchestration-services 379 Dec 22 21:07 /etc/puppetlabs/orchestration-services/conf.d/pcp-broker.conf

RPM: -rw-r--r--    1 root    root                     1149 Nov 22 21:37 /etc/puppetlabs/orchestration-services/conf.d/webserver.conf
Local: -rw-r-----. 1 pe-orchestration-services pe-orchestration-services 916 Dec 14 20:40 /etc/puppetlabs/orchestration-services/conf.d/webserver.conf

RPM: drwxrwx---    2 pe-orchepe-orche                    0 Nov 22 21:37 /opt/puppetlabs/server/data/orchestration-services
Local: drwxr-xr-x. 2 pe-orchestration-services pe-orchestration-services 27 Dec 14 20:42 /opt/puppetlabs/server/data/orchestration-services

RPM: -rw-------    1 root    root                      221 May 24  2015 /etc/securetty
Local: -r--------. 1 root root 49 Dec 15 17:30 /etc/securetty

RPM: drwxr-xr-x    2 root    root                        0 Jan 27  2014 /etc/stunnel
Local: drwxr-x---. 2 root stunnel 25 Dec 15 19:02 /etc/stunnel

RPM: -rw-r--r--    1 root    root                     2422 Aug  4  2015 /etc/security/limits.conf
Local: -rw-r-----. 1 root root 34 Dec 15 17:38 /etc/security/limits.conf

RPM: drwxr-x---    2 root    puppet                      0 Nov 27 01:34 /usr/share/simp/environments/simp
Local: drwxrws---. 7 root root 4096 Dec 14 21:18 /usr/share/simp/environments/simp

# This needs to be writable by the \'clam\' group for all components to function properly
RPM: -rw-r--r--    1 clamupdaclamupda                76781 Jun 13  2016 /var/lib/clamav/bytecode.cvd
Local: -rw-rw-r--. 1 clam clam 96528 Dec 15 19:02 /var/lib/clamav/bytecode.cvd

# This needs to be writable by the \'clam\' group for all components to function properly
RPM: -rw-r--r--    1 clamupdaclamupda            109143933 Jun 13  2016 /var/lib/clamav/main.cvd
Local: -rw-rw-r--. 1 clam clam 109143933 Jun 13  2016 /var/lib/clamav/main.cvd

RPM: -rw-r--r--    1 root    root                      119 Nov 25  2014 /etc/default/useradd
Local: -rw-------. 1 root root 110 Dec 15 17:30 /etc/default/useradd

RPM: -rw-r--r--    1 root    root                     2028 Nov 25  2014 /etc/login.defs
Local: -rw-r-----. 1 root root 644 Dec 15 17:30 /etc/login.defs

RPM: -rw-r--r--    1 root    root                   242153 Mar 16  2016 /etc/ssh/moduli
Local: -rw-------. 1 root root 242153 Mar 16  2016 /etc/ssh/moduli

RPM: drwxr-xr-x    2 clamupdaclamupda                    0 Jun 13  2016 /var/lib/clamav
Local: drwxrwxr-x. 2 clam clam 56 Dec 15 19:02 /var/lib/clamav

RPM: -rw-r--r--    1 root    root                      190 Nov 23 23:10 /etc/puppetlabs/puppetserver/conf.d/global.conf
Local: -rw-r-----. 1 pe-puppet pe-puppet 476 Dec 14 20:37 /etc/puppetlabs/puppetserver/conf.d/global.conf

RPM: -rw-r--r--    1 root    root                     1030 Nov 23 23:10 /etc/puppetlabs/puppetserver/conf.d/metrics.conf
Local: -rw-r-----. 1 pe-puppet pe-puppet 1215 Dec 14 20:40 /etc/puppetlabs/puppetserver/conf.d/metrics.conf

RPM: -rw-r--r--    1 root    root                     1766 Nov 23 23:10 /etc/puppetlabs/puppetserver/conf.d/pe-puppet-server.conf
Local: -rw-r-----. 1 pe-puppet pe-puppet 1960 Dec 14 20:37 /etc/puppetlabs/puppetserver/conf.d/pe-puppet-server.conf

RPM: -rw-r--r--    1 root    root                     1666 Nov 23 23:10 /etc/puppetlabs/puppetserver/conf.d/web-routes.conf
Local: -rw-r-----. 1 pe-puppet pe-puppet 1772 Dec 14 20:37 /etc/puppetlabs/puppetserver/conf.d/web-routes.conf

RPM: -rw-r--r--    1 root    root                      478 Nov 23 23:10 /etc/puppetlabs/puppetserver/conf.d/webserver.conf
Local: -rw-r-----. 1 pe-puppet pe-puppet 766 Dec 14 20:37 /etc/puppetlabs/puppetserver/conf.d/webserver.conf

RPM: drwxrwx---    2 pe-puppepe-puppe                    0 Nov 23 23:10 /opt/puppetlabs/server/data/puppetserver
Local: drwxr-xr-x. 10 pe-puppet pe-puppet 4096 Dec 20 18:04 /opt/puppetlabs/server/data/puppetserver

RPM: drwx------    2 pe-puppepe-puppe                    0 Nov 23 23:10 /var/log/puppetlabs/puppetserver
Local: drwxr-x---. 2 pe-puppet pe-puppet 4096 Dec 29 00:06 /var/log/puppetlabs/puppetserver

RPM: -rw-r--r--    1 root    root                      621 Nov 29 20:56 /etc/puppetlabs/puppetdb/conf.d/config.ini
Local: -rw-r-----. 1 pe-puppetdb pe-puppetdb 655 Dec 22 21:07 /etc/puppetlabs/puppetdb/conf.d/config.ini

RPM: -rw-r--r--    1 root    root                      550 Nov 29 20:56 /etc/puppetlabs/puppetdb/conf.d/database.ini
Local: -rw-r-----. 1 pe-puppetdb pe-puppetdb 966 Dec 14 20:41 /etc/puppetlabs/puppetdb/conf.d/database.ini

RPM: -rw-r--r--    1 root    root                     1081 Nov 29 20:56 /etc/puppetlabs/puppetdb/conf.d/jetty.ini
Local: -rw-r-----. 1 pe-puppetdb pe-puppetdb 1460 Dec 14 20:40 /etc/puppetlabs/puppetdb/conf.d/jetty.ini

RPM: -rw-r--r--    1 root    root                      358 Nov 29 20:56 /etc/puppetlabs/puppetdb/conf.d/rbac_consumer.conf
Local: -rw-r-----. 1 pe-puppetdb pe-puppetdb 651 Dec 14 20:40 /etc/puppetlabs/puppetdb/conf.d/rbac_consumer.conf

# Not changed by SIMP - File bug report with Puppet, Inc.
RPM: drwxrwx---    2 pe-puppepe-puppe                    0 Nov 29 20:56 /opt/puppetlabs/server/data/puppetdb
Local: drwxr-xr-x. 3 pe-puppetdb pe-puppetdb 36 Dec 14 20:41 /opt/puppetlabs/server/data/puppetdb

# Not changed by SIMP - File bug report with Puppet, Inc.
RPM: drwx------    2 pe-puppepe-puppe                    0 Nov 29 20:56 /var/log/puppetlabs/puppetdb
Local: drwxr-x---. 2 pe-puppetdb pe-puppetdb 4096 Dec 29 00:06 /var/log/puppetlabs/puppetdb

RPM: -rw-r--r--    1 root    root                     1756 Jun 17  2016 /etc/default/nss
Local: -rw-r-----. 1 root root 78 Dec 15 17:30 /etc/default/nss

# Needs to be fixed in SIMP to match the defaults
RPM: drwx--x--x    2 root    root                        0 Mar 16  2016 /var/empty/sshd
Local: drwxr-xr-x. 3 root root 16 Dec 15 19:01 /var/empty/sshd

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.daily
drwxr-xr-x    2 root    root                        0 Dec  3  2015 /etc/cron.daily
Local: dr-x------. 2 root root 111 Dec 27 21:37 /etc/cron.daily

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.hourly
drwxr-xr-x    2 root    root                        0 Dec  3  2015 /etc/cron.hourly
Local: dr-x------. 2 root root 44 Dec 22 21:02 /etc/cron.hourly

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.monthly
Local: dr-x------. 2 root root 6 Dec 27  2013 /etc/cron.monthly

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.weekly
Local: dr-x------. 2 root root 6 Dec 27  2013 /etc/cron.weekly

RPM: -rw-r--r--    1 root    root                      458 Jun 24  2015 /etc/rsyncd.conf
Local: -r--------. 1 root root 6047 Dec 27 21:37 /etc/rsyncd.conf

RPM: drwxr-xr-x    2 root    root                        0 Jul 12 09:03 /etc/httpd/conf
Local: drwxr-x---. 3 root apache 45 Dec 15 19:02 /etc/httpd/conf

RPM: drwxr-xr-x    2 root    root                        0 Jul 12 09:03 /etc/httpd/conf.d
Local: drwxr-x---. 2 root apache 50 Dec 15 19:02 /etc/httpd/conf.d

RPM: -rw-r--r--    1 root    root                    11753 Jul 12 09:00 /etc/httpd/conf/httpd.conf
Local: -rw-r-----. 1 root apache 7972 Dec 15 19:02 /etc/httpd/conf/httpd.conf

RPM: -rw-r--r--    1 root    root                    13077 Jul 12 09:03 /etc/httpd/conf/magic
Local: -rw-r-----. 1 root apache 12958 Dec 15 19:02 /etc/httpd/conf/magic

RPM: drwxr-xr-x    2 root    root                        0 Jul 12 09:03 /var/www
Local: drwxr-x---. 8 root apache 74 Dec 15 19:02 /var/www

RPM: drwxr-xr-x    2 root    root                        0 Jul 12 09:03 /var/www/cgi-bin
Local: drwxr-x---. 2 root apache 6 Jul 12 09:03 /var/www/cgi-bin

RPM: drwxr-xr-x    2 root    root                        0 Jul 12 09:03 /var/www/html
Local: drwxr-x---. 2 root apache 6 Jul 12 09:03 /var/www/html

RPM: -rw-r--r--    1 root    root                     3232 Sep  7  2015 /etc/rsyslog.conf
Local: -rw-------. 1 root root 42 Dec 20 18:08 /etc/rsyslog.conf

RPM: -rw-r--r--    1 root    root                      196 Sep  7  2015 /etc/sysconfig/rsyslog
Local: -rw-r-----. 1 root root 19 Dec 15 17:30 /etc/sysconfig/rsyslog

RPM: -rw-r-----    1 root    root                      701 Jan 14  2015 /etc/audit/auditd.conf
Local: -rw-------. 1 root root 454 Dec 15 17:30 /etc/audit/auditd.conf

RPM: -rwxr-xr-x    1 root    root                     6776 Dec  6 01:12 /etc/puppetlabs/activemq/activemq.xml
Local: -rw-r-----. 1 root pe-activemq 3982 Dec 14 20:40 /etc/puppetlabs/activemq/activemq.xml

RPM: -rwxr-xr-x    1 root    root                     7764 Dec  6 01:12 /etc/puppetlabs/activemq/jetty.xml
Local: -rw-r-----. 1 root pe-activemq 7764 Dec  6 01:12 /etc/puppetlabs/activemq/jetty.xml

RPM: -rwxr-xr-x    1 root    root                     2980 Dec  6 01:12 /etc/puppetlabs/activemq/log4j.properties
Local: -rw-r-----. 1 root pe-activemq 2980 Dec  6 01:12 /etc/puppetlabs/activemq/log4j.properties

RPM: drwxrwxr-x    2 pe-activpe-activ                    0 Dec  6 01:12 /var/run/puppetlabs/activemq
Local: drwxr-xr-x. 2 pe-activemq pe-activemq 60 Dec 22 20:52 /var/run/puppetlabs/activemq

RPM: -rw-r--r--    1 root    root                     1992 May  3  2016 /etc/ntp.conf
Local: -rw-------. 1 root ntp 319 Dec 22 15:14 /etc/ntp.conf

RPM: -rw-r--r--    1 root    root                       45 May  3  2016 /etc/sysconfig/ntpd
Local: -rw-r-----. 1 root root 62 Dec 15 17:30 /etc/sysconfig/ntpd

RPM: drwxr-xr-x    2 ntp     ntp                         0 May  3  2016 /var/lib/ntp
Local: drwxr-x---. 2 ntp ntp 18 Dec 29 17:52 /var/lib/ntp

RPM: -rw-r--r--    1 root    root                      775 Nov 23 00:58 /etc/puppetlabs/console-services/bootstrap.cfg
Local: -rw-r-----. 1 pe-console-services pe-console-services 933 Dec 14 20:43 /etc/puppetlabs/console-services/bootstrap.cfg

RPM: -rw-r--r--    1 root    root                        0 Nov 23 00:58 /etc/puppetlabs/console-services/conf.d/classifier.conf
Local: -rw-r-----. 1 pe-console-services pe-console-services 403 Dec 14 20:41 /etc/puppetlabs/console-services/conf.d/classifier.conf

RPM: -rw-r--r--    1 root    root                        0 Nov 23 00:58 /etc/puppetlabs/console-services/conf.d/console.conf
Local: -rw-r-----. 1 pe-console-services pe-console-services 2154 Dec 15 17:40 /etc/puppetlabs/console-services/conf.d/console.conf

RPM: -rw-r--r--    1 root    root                        0 Nov 23 00:58 /etc/puppetlabs/console-services/conf.d/global.conf
Local: -rw-r-----. 1 pe-console-services pe-console-services 189 Dec 14 20:40 /etc/puppetlabs/console-services/conf.d/global.conf

RPM: -rw-r--r--    1 root    root                        0 Nov 23 00:58 /etc/puppetlabs/console-services/conf.d/rbac.conf
Local: -rw-r-----. 1 pe-console-services pe-console-services 360 Dec 14 20:41 /etc/puppetlabs/console-services/conf.d/rbac.conf

RPM: -rw-r--r--    1 root    root                        0 Nov 23 00:58 /etc/puppetlabs/console-services/conf.d/webserver.conf
Local: -rw-r-----. 1 pe-console-services pe-console-services 1880 Dec 14 20:40 /etc/puppetlabs/console-services/conf.d/webserver.conf

RPM: drwxrwx---    2 pe-consope-conso                    0 Nov 23 00:58 /opt/puppetlabs/server/data/console-services
Local: drwxr-xr-x. 3 pe-console-services pe-console-services 39 Dec 14 20:43 /opt/puppetlabs/server/data/console-services

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/apache
Local: drwx------. 3 root root 16 Dec 14 21:13 /var/simp/rsync/RedHat/7/apache

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/bind_dns
Local: drwx------. 3 root root 20 Dec 14 21:13 /var/simp/rsync/RedHat/7/bind_dns

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/bind_dns/default
Local: drwx------. 3 root root 18 Dec 14 21:13 /var/simp/rsync/RedHat/7/bind_dns/default

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/bind_dns/default/named/etc
Local: drwxr-xr-x. 3 root root 50 Dec 14 21:13 /var/simp/rsync/RedHat/7/bind_dns/default/named/etc

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/bind_dns/default/named/var
Local: drwxr-xr-x. 4 root root 28 Dec 14 21:13 /var/simp/rsync/RedHat/7/bind_dns/default/named/var

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default
Local: drwx------. 3 root root 23 Dec 14 21:13 /var/simp/rsync/RedHat/7/default

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc
Local: drwxr-xr-x. 6 root root 90 Dec 14 21:13 /var/simp/rsync/RedHat/7/default/global_etc

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.daily
Local: dr-x------. 2 root root 6 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.daily

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.hourly
Local: dr-x------. 2 root root 6 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.hourly

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.monthly
Local: dr-x------. 2 root root 6 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.monthly

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.weekly
Local: dr-x------. 2 root root 6 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/cron.weekly

RPM: -rw-r-----    1 root    root                     1298 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/issue
Local: -rw-r--r--. 1 root root 1298 Nov 24 19:00 /var/simp/rsync/RedHat/7/default/global_etc/issue

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/dhcpd
Local: drwx------. 2 root root 23 Dec 14 21:13 /var/simp/rsync/RedHat/7/dhcpd

RPM: drwxr-x---    2 root    root                        0 Nov 24 19:00 /var/simp/rsync/RedHat/7/mcafee
Local: drwxr-xr-x. 2 root root 6 Nov 24 19:00 /var/simp/rsync/RedHat/7/mcafee

RPM: -rw-r--r--    1 root    root                      293 Feb 23  2016 /etc/pam.d/crond
Local: -rw-r-----. 1 root root 293 Feb 23  2016 /etc/pam.d/crond

RPM: dr-xr-x---    2 root    root                        0 May 25  2015 /root
Local: drwx------. 12 root root 4096 Dec 29 18:18 /root

RPM: drwxrwxr-x    2 root    mail                        0 May 25  2015 /var/spool/mail
Local: drwxr-xr-x. 2 root mail 67 Dec 29 00:12 /var/spool/mail

RPM: -rw-r--r--    1 root    root                      272 Jun 22  2015 /etc/pam.d/atd
Local: -rw-r-----. 1 root root 272 Jun 22  2015 /etc/pam.d/atd

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.daily
drwxr-xr-x    2 root    root                        0 Dec  3  2015 /etc/cron.daily
Local: dr-x------. 2 root root 111 Dec 27 21:37 /etc/cron.daily

RPM: drwxr-xr-x    2 root    root                        0 Dec 27  2013 /etc/cron.hourly
drwxr-xr-x    2 root    root                        0 Dec  3  2015 /etc/cron.hourly
Local: dr-x------. 2 root root 44 Dec 22 21:02 /etc/cron.hourly

RPM: drwxr-xr-x    2 root    root                        0 Dec  6 00:32 /etc/puppetlabs/code/environments/production
Local: lrwxrwxrwx. 1 root root 4 Dec 14 21:23 /etc/puppetlabs/code/environments/production -> simp

RPM: -rw-r--r--    1 root    root                      879 Dec  6 00:17 /etc/puppetlabs/code/environments/production/environment.conf
Local: -rw-r-----. 1 root pe-puppet 678 Nov 27 01:34 /etc/puppetlabs/code/environments/production/environment.conf

RPM: drwxr-xr-x    2 root    root                        0 Dec  6 00:18 /etc/puppetlabs/code/environments/production/hieradata
Local: drwxr-x---. 6 root pe-puppet 4096 Dec 29 16:58 /etc/puppetlabs/code/environments/production/hieradata

RPM: drwxr-xr-x    2 root    root                        0 Dec  6 00:18 /etc/puppetlabs/code/environments/production/manifests
Local: drwxr-x---. 2 root pe-puppet 33 Dec 15 21:53 /etc/puppetlabs/code/environments/production/manifests

RPM: drwxr-xr-x    2 root    root                        0 Dec  6 00:18 /etc/puppetlabs/code/environments/production/modules
Local: drwxr-x---. 71 root pe-puppet 4096 Dec 22 17:43 /etc/puppetlabs/code/environments/production/modules

RPM: -rw-r--r--    1 root    root                      634 Dec  6 00:17 /etc/puppetlabs/mcollective/server.cfg
Local: -rw-rw----. 1 root root 2620 Dec 14 20:38 /etc/puppetlabs/mcollective/server.cfg

RPM: -r--r--r--    1 root    root                     2036 Feb 23  2016 /etc/openldap/schema/collective.ldif
Local: -rw-r--r--. 1 root ldap 2036 Feb 23  2016 /etc/openldap/schema/collective.ldif

RPM: -r--r--r--    1 root    root                     6190 Feb 23  2016 /etc/openldap/schema/collective.schema
Local: -rw-r--r--. 1 root ldap 6190 Feb 23  2016 /etc/openldap/schema/collective.schema

RPM: -r--r--r--    1 root    root                     1845 Feb 23  2016 /etc/openldap/schema/corba.ldif
Local: -rw-r--r--. 1 root ldap 1845 Feb 23  2016 /etc/openldap/schema/corba.ldif

RPM: -r--r--r--    1 root    root                     8063 Feb 23  2016 /etc/openldap/schema/corba.schema
Local: -rw-r--r--. 1 root ldap 8063 Feb 23  2016 /etc/openldap/schema/corba.schema

RPM: -r--r--r--    1 root    root                    20612 Feb 23  2016 /etc/openldap/schema/core.ldif
Local: -rw-r--r--. 1 root ldap 20612 Feb 23  2016 /etc/openldap/schema/core.ldif

RPM: -r--r--r--    1 root    root                    20499 Feb 23  2016 /etc/openldap/schema/core.schema
Local: -rw-r--r--. 1 root ldap 20499 Feb 23  2016 /etc/openldap/schema/core.schema

RPM: -r--r--r--    1 root    root                    12006 Feb 23  2016 /etc/openldap/schema/cosine.ldif
Local: -rw-r--r--. 1 root ldap 12006 Feb 23  2016 /etc/openldap/schema/cosine.ldif

RPM: -r--r--r--    1 root    root                    73994 Feb 23  2016 /etc/openldap/schema/cosine.schema
Local: -rw-r--r--. 1 root ldap 73994 Feb 23  2016 /etc/openldap/schema/cosine.schema

RPM: -r--r--r--    1 root    root                     4842 Feb 23  2016 /etc/openldap/schema/duaconf.ldif
Local: -rw-r--r--. 1 root ldap 4842 Feb 23  2016 /etc/openldap/schema/duaconf.ldif

RPM: -r--r--r--    1 root    root                    10388 Feb 23  2016 /etc/openldap/schema/duaconf.schema
Local: -rw-r--r--. 1 root ldap 10388 Feb 23  2016 /etc/openldap/schema/duaconf.schema

RPM: -r--r--r--    1 root    root                     3330 Feb 23  2016 /etc/openldap/schema/dyngroup.ldif
Local: -rw-r--r--. 1 root ldap 3330 Feb 23  2016 /etc/openldap/schema/dyngroup.ldif

RPM: -r--r--r--    1 root    root                     3289 Feb 23  2016 /etc/openldap/schema/dyngroup.schema
Local: -rw-r--r--. 1 root ldap 3289 Feb 23  2016 /etc/openldap/schema/dyngroup.schema

RPM: -r--r--r--    1 root    root                     3481 Feb 23  2016 /etc/openldap/schema/inetorgperson.ldif
Local: -rw-r--r--. 1 root ldap 3481 Feb 23  2016 /etc/openldap/schema/inetorgperson.ldif

RPM: -r--r--r--    1 root    root                     6267 Feb 23  2016 /etc/openldap/schema/inetorgperson.schema
Local: -rw-r--r--. 1 root ldap 6267 Feb 23  2016 /etc/openldap/schema/inetorgperson.schema

RPM: -r--r--r--    1 root    root                     2979 Feb 23  2016 /etc/openldap/schema/java.ldif
Local: -rw-r--r--. 1 root ldap 2979 Feb 23  2016 /etc/openldap/schema/java.ldif

RPM: -r--r--r--    1 root    root                    13901 Feb 23  2016 /etc/openldap/schema/java.schema
Local: -rw-r--r--. 1 root ldap 13901 Feb 23  2016 /etc/openldap/schema/java.schema

RPM: -r--r--r--    1 root    root                     2082 Feb 23  2016 /etc/openldap/schema/misc.ldif
Local: -rw-r--r--. 1 root ldap 2082 Feb 23  2016 /etc/openldap/schema/misc.ldif

RPM: -r--r--r--    1 root    root                     2387 Feb 23  2016 /etc/openldap/schema/misc.schema
Local: -rw-r--r--. 1 root ldap 2387 Feb 23  2016 /etc/openldap/schema/misc.schema

RPM: -r--r--r--    1 root    root                     6809 Feb 23  2016 /etc/openldap/schema/nis.ldif
Local: -rw-r--r--. 1 root ldap 6809 Feb 23  2016 /etc/openldap/schema/nis.ldif

RPM: -r--r--r--    1 root    root                     7640 Feb 23  2016 /etc/openldap/schema/nis.schema
Local: -rw-r--r--. 1 root ldap 7640 Feb 23  2016 /etc/openldap/schema/nis.schema

RPM: -r--r--r--    1 root    root                     3308 Feb 23  2016 /etc/openldap/schema/openldap.ldif
Local: -rw-r--r--. 1 root ldap 3308 Feb 23  2016 /etc/openldap/schema/openldap.ldif

RPM: -r--r--r--    1 root    root                     1514 Feb 23  2016 /etc/openldap/schema/openldap.schema
Local: -rw-r--r--. 1 root ldap 1514 Feb 23  2016 /etc/openldap/schema/openldap.schema

RPM: -r--r--r--    1 root    root                     6904 Feb 23  2016 /etc/openldap/schema/pmi.ldif
Local: -rw-r--r--. 1 root ldap 6904 Feb 23  2016 /etc/openldap/schema/pmi.ldif

RPM: -r--r--r--    1 root    root                    20467 Feb 23  2016 /etc/openldap/schema/pmi.schema
Local: -rw-r--r--. 1 root ldap 20467 Feb 23  2016 /etc/openldap/schema/pmi.schema

RPM: -r--r--r--    1 root    root                     4356 Feb 23  2016 /etc/openldap/schema/ppolicy.ldif
Local: -rw-r--r--. 1 root ldap 4356 Feb 23  2016 /etc/openldap/schema/ppolicy.ldif

RPM: -r--r--r--    1 root    root                    19963 Feb 23  2016 /etc/openldap/schema/ppolicy.schema
Local: -rw-r--r--. 1 root ldap 19963 Feb 23  2016 /etc/openldap/schema/ppolicy.schema

RPM: -rw-r--r--    1 root    root                      527 Feb 23  2016 /etc/sysconfig/slapd
Local: -rw-r-----. 1 root root 42 Dec 15 17:29 /etc/sysconfig/slapd

# Group access does not weaker permissions
RPM: drwx------    2 ldap    ldap                        0 Feb 23  2016 /var/lib/ldap
Local: drwxrwx---. 4 ldap ldap 99 Dec 27 15:55 /var/lib/ldap

# Required for user-based virus scanning
RPM: drwxr-x---    2 root    root                        0 Nov 27 01:33 /var/simp/rsync/RedHat/7/clamav
Local: drwxrwxr-x. 2 clam clam 56 Dec 14 21:16 /var/simp/rsync/RedHat/7/clamav

# Required for user-based virus scanning
RPM: -rw-r-----    1 root    root                    96528 Nov 24 22:20 /var/simp/rsync/RedHat/7/clamav/bytecode.cvd
Local: -rw-rw-r--. 1 clam clam 96528 Nov 24 22:20 /var/simp/rsync/RedHat/7/clamav/bytecode.cvd

# Required for user-based virus scanning
RPM: -rw-r-----    1 root    root                 63135232 Nov 27 01:33 /var/simp/rsync/RedHat/7/clamav/daily.cld
Local: -rw-rw-r--. 1 clam clam 63135232 Nov 27 01:33 /var/simp/rsync/RedHat/7/clamav/daily.cld

# Required for user-based virus scanning
RPM: -rw-r-----    1 root    root                109143933 Nov 24 22:19 /var/simp/rsync/RedHat/7/clamav/main.cvd
Local: -rw-rw-r--. 1 clam clam 109143933 Nov 24 22:19 /var/simp/rsync/RedHat/7/clamav/main.cvd

RPM: drwx--x--x    2 sssd    sssd                        0 Jul 14 10:33 /etc/sssd
Local: drwxr-x---. 3 root root 52 Dec 15 17:38 /etc/sssd

# SIMP should restrict global access
RPM: drwx------    2 pe-postgpe-postg                    0 Dec  6 01:33 /opt/puppetlabs/server/data/postgresql
Local: drwxr-xr-x. 8 pe-postgres pe-postgres 4096 Dec 14 20:39 /opt/puppetlabs/server/data/postgresql

# SIMP should restrict global access
RPM: drwx------    2 pe-postgpe-postg                    0 Dec  6 01:33 /opt/puppetlabs/server/data/postgresql/9.4
Local: drwxr-xr-x. 4 pe-postgres pe-postgres 31 Dec 14 20:38 /opt/puppetlabs/server/data/postgresql/9.4

RPM: drwxrwxr-x    2 pe-postgpe-postg                    0 Dec  6 01:33 /var/run/puppetlabs/postgresql
Local: drwxr-xr-x. 2 pe-postgres pe-postgres 80 Dec 22 20:52 /var/run/puppetlabs/postgresql'''
        },
        "xccdf_org:ssgproject:content_rule_rpm_verify_hashes" => {
          "remediation" => "TODO"
        },
        "xccdf_org:ssgproject:content_rule_install_mcafee_antivirus" => {
          "remediation" =>
'''We use ClamAV in place of Mcafee, and it is enabled by default.

If ClamAV is *not* enabled, set the following in Hiera data:
---
classes:
  - clamav''',
        },
        "xccdf_org:ssgproject:content_rule_grub2_enable_fips_mode" => {
          "remediation" => "TODO"
        },
        "xccdf_org:ssgproject:content_rule_instaltled_OS_is_certified" => {
          "remediation" => "It is the job of the vendor to ensure the OS is maintained and certified"
        },
        "xccdf_org:ssgproject:content_rule_sudo_remove_nopasswd" => {
          "remediation" =>
'''It is generally recommended that SIMP systems do not use passwords on systems and only allow authentication via SSH keys. This necessarily precludes the use of passwords to authenticate via sudo.

This may be configured differently and, by default, is restricted to only the administrators and security groups.

 cat /etc/sudoers | grep NOP
%administrators    ALL=(root) NOPASSWD:EXEC:SETENV: /bin/rm -rf /etc/puppetlabs/puppet/ssl
%administrators    ALL=(ALL) NOPASSWD:EXEC:SETENV: /usr/bin/sudosh
%administrators    ALL=(root) NOPASSWD:EXEC:SETENV: /usr/sbin/puppetca
%administrators    ALL=(root) NOPASSWD:EXEC:SETENV: /usr/sbin/puppetd
%security    ALL=(root) NOPASSWD:EXEC:SETENV: AUDIT'''
        },
        "xccdf_org:ssgproject:content_rule_no_files_unowned_by_user" => {
          "remediation" => "The SIMP server serves files over encrypted rsync which require proper numeric ownership after transfer. The server, not requiring the rsync specified users will show the files as unknowned. This is correct and must not be modified if the client systems are to maintain proper functionality."
        },
        "xccdf_org:ssgproject:content_rule_file_permissions_ungroupowned" => {
          "remediation" => "The SIMP server serves files over encrypted rsync which require proper numeric ownership after transfer. The server, not requiring the rsync specified users will show the files as unknowned. This is correct and must not be modified if the client systems are to maintain proper functionality."
        },
        "xccdf_org:ssgproject:content_rule_dir_perms_world_writable_system_owned" => {
          "remediation" => "TODO"
        },
        "xccdf_org:ssgproject:content_rule_accounts_maximum_age_login_defs" => {
          "remediation" =>
'''SIMP sets PASS_MAX_DAYS to 180 by default per most common guidance.

The scan checks for 60 days but this tends to be too short for the enforced password complexity requirements.

If you need a shorter duration set the following in Hiera:

---
simplib::login_defs::pass_max_days: \'60\''''
        },
        "xccdf_org:ssgproject:content_rule_account_disable_post_pw_expiration" => {
          "remediation" => "The check is incorrect.  Value defaults to STIG recommendation."
        },
        "xccdf_org:ssgproject:content_rule_accounts_password_pam_retry" => {
          "remediation" =>
'''The policy indicates that pam_cracklib may be used in lieu of pam_pwquality. SIMP has not yet changed to use pam_pwquality.

grep -o retry=3 /etc/pam.d/system-auth
retry=3'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_password_pam_difok" => {
          "remediation" =>
'''The policy indicates that pam_cracklib may be used in lieu of pam_pwquality. SIMP has not yet changed to use pam_pwquality.

 grep -Po "difok=.*? "  /etc/pam.d/system-auth
difok=8'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_password_pam_minclass" => {
          "remediation" =>
'''The policy indicates that pam_cracklib may be used in lieu of pam_pwquality. SIMP has not yet changed to use pam_pwquality.

grep -Po "minclass=.*? "  /etc/pam.d/system-auth
minclass=4

Though minclass is set to 4, setting the *credit items to -1 ensures that they must be used in the password which renders this setting useless.'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_passwords_pam_faillock_deny" => {
          "remediation" =>
'''grep -P "deny=.*? "  /etc/pam.d/system-auth
auth     required      pam_faillock.so preauth silent deny=5 even_deny_root audit unlock_time=900 root_unlock_time=60 fail_interval=900

Setting deny to less than 5 was causing premature lockouts when presented with alternate authentication systems and also, at times, when using sudo and attempting to ^C out of the session. This may be fixed in the latest releases of RHEL, but has not been verified.'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_passwords_pam_faillock_unlock_time" => {
          "remediation" =>
'''Waiting for more than 15 minutes is not conducive to effective security and causes a heavy burden on helpdesk systems relating to password resets where the user remembers their password but simply typed it incorrectly multiple times.

Even the most rudmentary log auditing system should be able to identify repeated failed logins over multi-15 minute boundaries.

grep -P "unlock_time=.*? "  /etc/pam.d/system-auth
auth     required      pam_faillock.so preauth silent deny=5 even_deny_root audit unlock_time=900 root_unlock_time=60 fail_interval=900
This can be made compliant using the following Hieradata:

---
pam::unlock_time: 604800'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_passwords_pam_faillock_deny_root" => {
          "remediation" =>
''' False positive

grep -P "unlock_time=.*? "  /etc/pam.d/system-auth
auth     required      pam_faillock.so preauth silent deny=5 even_deny_root audit unlock_time=900 root_unlock_time=60 fail_interval=900'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_passwords_pam_faillock_interval" => {
          "remediation" =>
'''False Positive

grep -P "faillock"  /etc/pam.d/system-auth
auth     required      pam_faillock.so preauth silent deny=5 even_deny_root audit unlock_time=900 root_unlock_time=60 fail_interval=900
account     required      pam_faillock.so'''
        },
        "xccdf_org.ssgproject.content_rule_accounts_umask_etc_login_defs" => {
          "remediation" => "We default the UMASK to 007 because 077 is too difficult to work with everywhere. Recommend changing locally, as needed."
        },
        "xccdf_org:ssgproject:content_rule_accounts_have_homedir_login_defs" => {
          "remediation" =>
'''False Positive.

grep CREATE_HOME /etc/login.defs 
CREATE_HOME yes'''
        },
        "xccdf_org:ssgproject:content_rule_accounts_tmout" => {
          "remediation" =>
'''SIMP manages TMOUT in `/etc/profile.d/simp.*`. SIMP defaults to a timeout of 15, but it can be changed to 10 by setting the following in Hiera data:

---
useradd::etc_profile::session_timeout: 10'''
        },
        "xccdf_org.ssgproject.content_rule_bootloader_password" => {
          "remediation" =>
'''False Positive. The script should check the built /etc/grub2.cfg. Checking the configuration files is not useful if they have not been applied.

grep pbkdf /etc/grub2.cfg
password_pbkdf2 root grub.pbkdf2.sha512.10000.83E1E6452551'''
        },
        "xccdf_org:ssgproject:content_rule_package_screen_installed" => {
          "remediation" => "SIMP does not manage the screen package by default. `yum install screen`",
          "notes" => "We should consider installing this by default"
        },
        "xccdf_org:ssgproject:content_rule_smartcard_auth" => {
          "remediation" => "SIMP does not currently support smart card (CAC) authentication, but development is in progress."
        },
        "xccdf_org:ssgproject:content_rule_disable_ctrlaltdel_reboot" => {
          "remediation" =>
'''By default, SIMP disables ctrl-alt-del reboot and creates a logged entry, if pressed.  To disable per the STIG recommendations, set the following in Hiera data:

---
simp::ctrl_alt_del::enable: false
simp::ctrl_alt_del::log: false''' 
        },
        "xccdf_org:ssgproject:content_rule_banner_etc_issue" => {
          "remediation" =>
'''SIMP provides a login banner, but it is not the DoD default.  Set the following in Hiera data:

---
issue::profile: us_dod''',
          "notes" => "We should add a us_dod_stig profile"
        },
        "xccdf_org:ssgproject:content_rule_sysctl_net_ipv4_ip_forward" => {
          "remediation" =>
'''This is an antequated rule given that almost all environments run subsystems that require some sort of internal routing. To support these subsystems, SIMP needs to manage IP forwarding rules elsewhere and the system defaults are correct.

To disable ipv4 forwarding, include the following in a manifest:

sysctl { "net.ipv4.ip_forward":
  ensure => present,
  value  => "0",
}''',
          "notes" => "We should add the option to toggle ipv4 forwarding to simp::sysctl"
        },
        "xccdf_org:ssgproject:content_rule_sysctl_net_ipv6_conf_all_accept_source_route" => {
          "remediation" =>
'''Per the description, the check is incorrect.

sysctl -a | grep source_route
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.ens192.accept_source_route = 0
net.ipv4.conf.lo.accept_source_route = 1
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv6.conf.ens192.accept_source_route = 0
net.ipv6.conf.lo.accept_source_route = 0''',
          "notes" => "We should add a setting to explicitly set net.ipv6.conf.all.accept_source_route=0 to simp::sysctl"
        },
        "xccdf_org:ssgproject:content_rule_service_firewalld_enabled" => {
          "remediation" =>
'''To use the same code to manage both EL6 and EL7 systems, SIMP manages iptables directly. Additionally, for server systems, most admins that we have encountered find it easier to deal with direct IPTables rules when debugging firewall issues.

Finally, firewalld hooks into dbus which opens the possibility of software that can independently manage firewall settings at run time without explicit authorization.

When EL6 is no longer supported SIMP may move to having firewalld support, but not before then.''',
        },
        "xccdf_org:ssgproject:content_rule_set_firewalld_default_zone" => {
          "remediation" =>
'''SIMP provides full IPTables management by default with a "default drop" policy.

iptables-save
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:LOCAL-INPUT - [0:0]
-A INPUT -j LOCAL-INPUT
-A FORWARD -j LOCAL-INPUT
-A LOCAL-INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A LOCAL-INPUT -i lo -j ACCEPT
-A LOCAL-INPUT -p tcp -m state --state NEW -m tcp -m multiport --dports 22 -j ACCEPT
-A LOCAL-INPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT
-A LOCAL-INPUT -m pkttype --pkt-type broadcast -j DROP
-A LOCAL-INPUT -m addrtype --src-type MULTICAST -j DROP
-A LOCAL-INPUT -m state --state NEW -j LOG --log-prefix "IPT:"
-A LOCAL-INPUT -j DROP
COMMIT'''
        },
        "xccdf_org:ssgproject:content_rule_network_configure_name_resolution" => {
          "remediation" =>
'''SIMP cannot pre determine an environment\'s DNS servers.  To specify them, set the following in Hiera data:

---
simp_options::dns::servers: [\'1.2.3.4\',\'5.6.7.8\']'''
        },
        "xccdf_org:ssgproject:content_rule_rsyslog_cron_logging" => {
          "remediation" =>  '''
False Positive.  By default, cron is logged, per simp_rsyslog::default_logs.

grep cron /etc/rsyslog.simp.d/99_simp_local/ZZ_default.conf 
*.info;mail.none;authpriv.none;cron.none;local6.none;local5.none action(type="omfile" file="/var/log/messages")
cron.*  action(type="omfile" file="/var/log/cron")'''
        },
        "xccdf_org:ssgproject:content_rule_rsyslog_remote_loghost" => {
          "remediation" =>
'''To set up a remote log server, follow the SIMP documentation https://simp.readthedocs.io/en/master/user_guide/HOWTO/Central_Log_Collection/Rsyslog.html. Once set up, the scan may still fail, since it does not take into account the new Rainerscript format and does not process the full configuration.

 cat /etc/rsyslog.simp.d/10_simp_remote/simp_stock_remote.conf
ruleset(
  name="simp_stock_remote_ruleset"
) {
  action(
    type="omfwd"
    protocol="tcp"
    target="1.2.3.4"
    port="6514"
    TCP_Framing="traditional"
    ZipLevel="0"
    StreamDriverMode="1"
    StreamDriverAuthMode="x509/name"
    StreamDriverPermittedPeers="*.my.domain"
    ResendLastMSGOnReconnect="on"
  )
}

if $programname == \'sudosh\' or $programname == \'yum\' or $syslogfacility-text == \'cron\' or $syslogfacility-text == \'authpriv\' or $syslogfacility-text == \'local5\' or $syslogfacility-text == \'local6\' or $syslogfacility-text == \'local7\' or $syslogpriority-text == \'emerg\' or ( $syslogfacility-text == \'kern\' and $msg startswith \'IPT:\' ) then
call simp_stock_remote_ruleset'''
        },
        "xccdf_org:ssgproject:content_rule_service_kdump_disabled" => {
          "remediation" =>
'''SIMP does not disable kdump by default.  To stop the service and disable it, add the following to a manifest:

service { \'kdump\':
  ensure => \'stopped\',
  enable => false
}'''
        },
        "xccdf_org:ssgproject:content_rule_sshd_allow_only_protocol2" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set Protocol, set the following in a manifest:

sshd_config { \'Protocol\': value => \'2\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_disable_kerb_auth" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set KerberosAuthentication, set the following in a manifest:

sshd_config { \'KerberosAuthentication\': value => \'no\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_enable_strictmodes" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set StrictModes, set the following in a manifest:

sshd_config { \'StrictModes\': value => \'yes\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_set_idle_timeout" => {
          "remediation" =>
'''While this is laudable, all of our shell connections have the TMOUT parameter set. Additionally, it was found that enabling this in the field caused extreme disruption in workflow. For instance, sessions would timeout when working across multiple windows on complex issues and while reading man pages or logs during troubleshooting.  To explicitly set ClientAliveInterval, set the following in a manifest:

sshd_config { \'ClientAliveInterval\': value => \'600\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org.ssgproject.content_rule_sshd_set_keepalive" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set ClientAliveCountMax, set the following in a manifest:

sshd_config { \'ClientAliveCountMax\': value => \'0\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_disable_user_known_hosts" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set IgnoreUserKnownHosts, set the following in a manifest:

sshd_config { \'IgnoreUserKnownHosts\': value => \'yes\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_disable_rhosts_rsa" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set RhostsRSAAuthentication, set the following in a manifest:

sshd_config { \'RhostsRSAAuthentication\': value => \'no\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_do_not_permit_user_env" => {
          "remediation" =>
'''False Positive.  If the system default passes, the scan should pass.  To explicitly set PermitUserEnvironment, set the following in a manifest:

sshd_config { \'PermitUserEnvironment\': value => \'no\' }''',
          "notes" => "Add this to ssh::server::conf"
        },
        "xccdf_org:ssgproject:content_rule_sshd_use_approved_ciphers" => {
          "remediation" =>
'''False Positive.  By default in FIPS mode, fallback ciphers will be used, which are all FIPS approved.

grep Ciphers /etc/ssh/sshd_config 
# Ciphers and keying
Ciphers aes256-ctr,aes192-ctr,aes128-ctr'''
        },
        "xccdf_org:ssgproject:content_rule_sshd_use_approved_macs" => {
          "remediation" =>
'''False Positive. By default in FIPS mode, fips macs will be used, which are all FIPS approved.

grep MAC /etc/ssh/sshd_config 
MACs hmac-sha2-256,hmac-sha1'''
        },
        "xccdf_org:ssgproject:content_rule_ntp_set_maxpoll" => {
          "remediation" => "Currently, there is no way to specify maxpoll unless you specify an ntp server with default options.",
          "notes" => "We need to give users a way to specify an options hash."
        },
        "xccdf_org:ssgproject:content_rule_ldap_client_start_tls" => {
          "remediation" =>
'''False Positive.  The scan should not assume that authconfig is being used and should simply check the system.  This may also be affected by the use of sssd which would completely preclude the use of the pam_ldap.conf settings.

grep -i tls /etc/sssd/sssd.conf 
ldap_id_use_start_tls = true

grep -i ssl /etc/sssd/sssd.conf
ldap_tls_cipher_suite = HIGH:-SSLv2'''
        },
        "xccdf_org:ssgproject:content_rule_snmpd_not_default_password" => {
          "remediation" => "TODO"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_chmod" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_chown" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fchmod" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fchmodat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fchown" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fchownat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fremovexattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_fsetxattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_lchown" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_lremovexattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_lsetxattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_removexattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_dac_modification_setxattr" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_login_events_faillock" => {
          "remediation" =>
'''False Positive.

grep faillock /etc/audit/rules.d/50_base.rules 
-w /var/run/faillock -p wa -k logins'''
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_creat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_open" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_openat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_open_by_handle_at" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_truncate" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_unsuccessful_file_modification_ftruncate" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_execution_semanage" => {
          "remediation" => "SIMP does not currently support this audit",
          "notes" => "SIMP should support this audit"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_execution_setsebool" => {
          "remediation" => "SIMP does not currently support this audit",
          "notes" => "SIMP should support this audit"
        },
        "xccdf_org.ssgproject.content_rule_audit_rules_execution_chcon" => {
          "remediation" => "SIMP does not currently support this audit",
          "notes" => "SIMP should support this audit"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_execution_restorecon" => {
          "remediation" => "SIMP does not currently support this audit",
          "notes" => "SIMP should support this audit"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_privileged_commands" => {
          "remediation" =>
'''The rule that is dictated by the SSG relies on generating file lists and is untenable over time as well as being file system intensive when it is run. It also misses suid/sgid binaries that are run on remote partitions.

The SIMP audit rules check for binary execution where the auid is not 0 and the uid is 0. This should capture the execution of any suid binary regardless of location.

grep su-root-activity /etc/audit/rules.d/*
/etc/audit/rules.d/50_base.rules:-a always,exit -F arch=b64 -F auid!=0 -F uid=0 -S capset -S mknod -S pivot_root -S quotactl -S setsid -S settimeofday -S setuid -S swapoff -S swapon -k su-root-activity
/etc/audit/rules.d/50_base.rules:-a always,exit -F arch=b32 -F auid!=0 -F uid=0 -S capset -S mknod -S pivot_root -S quotactl -S setsid -S settimeofday -S setuid -S swapoff -S swapon -k su-root-activity''',
          "notes" => "We should audit passwd, unix_chkpwd, pgasswd, chage, userhelper, su, sudo, sudoedit, chsch, umount, postdrop, postqueue, ssh-keysign, pt_chown, crontab, pam_timestamp_check"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_file_deletion_events_rmdir" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_file_deletion_events_unlink" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_file_deletion_events_unlinkat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_file_deletion_events_rename" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_file_deletion_events_renameat" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_system_shutdown" => {
          "remediation" => "TODO",
          "notes" => "Consider supporting this"
        },
        "xccdf_org:ssgproject:content_rule_audit_rules_media_export" => {
          "remediation" => "False Positive. The scan does not properly handle optimized rules which are recommended by the prose guide.  See /etc/audit/rules.d/50_base.rules."
        },
      }
    }
  }
}

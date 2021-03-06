# === Copyright
#
# Copyright 2014, Deutsche Telekom AG
# Licensed under the Apache License, Version 2.0 (the "License");
# http://www.apache.org/licenses/LICENSE-2.0
#

# == Class: os_hardening::minimize_access
#
# Configures profile.conf.
#
class os_hardening::minimize_access (
  Boolean $allow_change_user   = false,
  Array   $always_ignore_users =
    ['root','sync','shutdown','halt'],
  Array   $ignore_users        = [],
  Array   $folders_to_restrict =
    ['/usr/local/games','/usr/local/sbin','/usr/local/bin','/usr/bin','/usr/sbin','/sbin','/bin'],
  String  $shadowgroup         = 'root',
  String  $shadowmode          = '0600',
  Integer $recurselimit        = 5,
  Boolean $strict_tcp_wrappers = false,
  String  $allow_ssh_from      = 'ALL',
  String  $dir_mode            = '0750',
) {

  case $::operatingsystem {
    redhat, fedora: {
      $nologin_path = '/sbin/nologin'
      $shadow_path = ['/etc/shadow', '/etc/gshadow']
    }
    debian, ubuntu: {
      $nologin_path = '/usr/sbin/nologin'
      $shadow_path = ['/etc/shadow', '/etc/gshadow']
    }
    default: {
      $nologin_path = '/sbin/nologin'
      $shadow_path = '/etc/shadow'
    }
  }

  # remove write permissions from path folders ($PATH) for all regular users
  # this prevents changing any system-wide command from normal users
  ensure_resources ('file',
  { $folders_to_restrict => {
      ensure       => directory,
      links        => follow,
      mode         => 'go-w',
      recurse      => true,
      recurselimit => $recurselimit,
    }
  })

  # shadow must only be accessible to user root
  file { $shadow_path:
    ensure => file,
    owner  => 'root',
    group  => $shadowgroup,
    mode   => $shadowmode,
  }

  # su must only be accessible to user and group root
  if $allow_change_user == false {
    file { '/bin/su':
      ensure => file,
      links  => follow,
      owner  => 'root',
      group  => 'root',
      mode   => '0750',
    }
  } else {
    file { '/bin/su':
      ensure => file,
      links  => follow,
      owner  => 'root',
      group  => 'root',
      mode   => '4755',
    }
  }

  # retrieve system users through custom fact
  $system_users = split($::retrieve_system_users, ',')

  # build array of usernames we need to verify/change
  $ignore_users_arr = union($always_ignore_users, $ignore_users)

  # build a target array with usernames to verify/change
  $target_system_users = difference($system_users, $ignore_users_arr)

  # ensure accounts are locked (no password) and use nologin shell
  user { $target_system_users:
    ensure   => present,
    shell    => $nologin_path,
    password => '*',
  }

  # this removes access from users to run at or cron, only root can do so
  file { ['/etc/cron.allow', '/etc/at.allow']:
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }

  # tighten restrictions on crontab for CIS DIL Benchmark 5.1.2
  file { '/etc/crontab':
    ensure => file,
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
  }

  $cron_directories = [
    '/etc/cron.d',
    '/etc/cron.monthly',
    '/etc/cron.weekly',
    '/etc/cron.daily',
    '/etc/cron.hourly',
  ]

  # tighten restrictions on cron directory for CIS DIL Benchmark 5.1.3-7
  file { $cron_directories:
    ensure => directory,
    mode   => '0700',
    owner  => 'root',
    group  => 'root',
  }

  $logfiles_with_default_incorrect_permissions = [
    '/var/log/faillog',
    '/var/log/dpkg.log',
    '/var/log/alternatives.log',
    '/var/log/wtmp',
    '/var/log/installer/hardware-summary',
    '/var/log/installer/lsb-release',
    '/var/log/installer/status',
    '/var/log/lastlog',
    '/var/log/apt/history.log',
    '/var/log/apt/eipp.log.xz',
    '/var/log/',
  ]

  # these log files are deployed by the installer with incorrect permissions, fix needed for CIS DIL Benchmark 4.2.4
  file { $logfiles_with_default_incorrect_permissions:
    mode => 'g-w,o-rwx',
  }

  if $strict_tcp_wrappers {
    # CIS DIL Benchmark 3.4.2 - 3.4.5
    file { '/etc/hosts.deny':
      content => 'ALL: ALL',
      mode    => '0644',
      owner   => 'root',
      group   => 'root';
    }

    if $allow_ssh_from != false {
      file_line { 'Set allowed hosts for sshd in tcp wrappers config':
        line  => "sshd: ${allow_ssh_from}",
        match => '^sshd:\s+.*',
        path  => '/etc/hosts.allow',
      }
    }
  }

  # i do not know how this works on anything else than debian/ubuntu
  if $::operatingsystem == 'debian' or $::operatingsystem == 'ubuntu' {
    file_line { 'CIS DIL Benchmark 6.2.8 - Ensure user home directories permissions are 750 or more restrictive':
      path  => '/etc/adduser.conf',
      match => '^DIR_MODE=',
      line  => "DIR_MODE=${dir_mode}";
    }
  }
}


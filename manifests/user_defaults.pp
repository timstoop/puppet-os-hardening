# === Copyright
#
# Copyright 2018, Kumina B.V., Tim Stoop
# Licensed under the Apache License, Version 2.0 (the "License");
# http://www.apache.org/licenses/LICENSE-2.0
#

# == Class: os_hardening::user_defaults
#
# Configures user defaults for shells
#
class os_hardening::user_defaults (
  Boolean $manage_global_bashrc = false,
  String  $default_umask        = '027',
) {

  if $manage_global_bashrc {
    case $::operatingsystem {
      debian, ubuntu: {
        $global_bashrc = '/etc/bash.bashrc'
        $bashrc_template = 'os_hardening/bash.bashrc.debian.erb'
      }
      default: {
        fail("Sorry! This is not implemented for platform $::operatingsystem.")
      }
    }

    # set the file
    file { $global_bashrc:
        ensure  => file,
        content => template($bashrc_template),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
    }
  }

}


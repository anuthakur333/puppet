# javaexec
# run the silent install
# set the default java links
# set this java as default

define jrockit::javaexec (
  $path        = undef,
  $version     = undef,
  $fullversion = undef,
  $jdkfile     = undef,
  $setDefault  = undef,
  $user        = undef,
  $jreInstallDir = undef,
  $group       = undef,
  ) {

  # install jdk
  case $::operatingsystem {
    CentOS, RedHat, OracleLinux, Ubuntu, Debian: {
      $execPath     = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'
      $javaInstall  = $jreInstallDir
      $silentfile   = "${path}/silent${version}.xml"

      Exec {
        logoutput   => true,
        path        => $execPath,
        user        => $user,
        group       => $group,
      }

      # check java install folder
      if ! defined(File[$javaInstall]) {
        file { $javaInstall :
          ensure => directory,
          path   => $javaInstall,
          mode   => '0755',
        }
      }

      # Create the silent install xml
      file { "silent.xml ${version}":
        ensure  => present,
        path    => $silentfile,
        replace => 'yes',
        content => template('jrockit/jrockit-silent.xml.erb'),
        require => File[$path],
      }

      # Do the installation but only if the directry doesn't exist
      exec { 'installjrockit':
        command   => "${jdkfile} -mode=silent -silent_xml=${silentfile}",
        cwd       => $path,
        path      => $path,
        logoutput => true,
        require   => File["silent.xml ${version}"],
        creates   => "${jreInstallDir}/${fullversion}",
      }

      # java link to latest
      file { "${jreInstallDir}/latest":
        ensure  => link,
        target  => "${jreInstallDir}/${fullversion}",
        mode    => '0755',
        require => Exec['installjrockit'],
      }

      # java link to default
      file { "${jreInstallDir}/default":
        ensure  => link,
        target  => "${jreInstallDir}/latest",
        mode    => '0755',
        require => File["${jreInstallDir}/latest"],
      }

      # Add to alternatives and set as the default if required
      case $::operatingsystem {
        CentOS, RedHat, OracleLinux: {
          # set the java default
          exec { 'install alternatives':
            command => "alternatives --install /usr/bin/java java ${jreInstallDir}/${fullversion}/bin/java 17065",
            require => File["${jreInstallDir}/default"],
          }

          if $setDefault == true {
            exec { 'default alternatives':
              command => "alternatives --set java ${jreInstallDir}/${fullversion}/bin/java",
              require => Exec['install alternatives'],
            }
          }

        }

        Ubuntu, Debian: {
          # set the java default
          exec { 'install alternatives':
            command => "update-alternatives --install /usr/bin/java java ${jreInstallDir}/${fullversion}/bin/java 17065",
            require => File["${jreInstallDir}/default"],
          }

          if $setDefault == true {
            exec { 'default alternatives':
              command => "update-alternatives --set java ${jreInstallDir}/${fullversion}/bin/java",
              require => Exec['install alternatives'],
            }
          }
        }
        default: {
          fail('Unrecognized operating system')
        }
      }
    }
    default: {
      fail('Unrecognized operating system')
    }
  }
}

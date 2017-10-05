#!/bin/bash

#printenv

: ${PACKAGES:='factor puppet-agent'}
: ${REPOS:=''}
: ${MODULES:='puppetlabs-stdlib rcoleman-puppet_module'}
: ${MODULE_PATH:='/opt/puppetlabs/puppet/modules'}
: ${SUDO_FLAGS:='-iE'}

package_cmd=$( set -- `which ${package_cmd:-yum rpm apt-get dpkg} 2>/dev/null`; echo $1; )
[ -x "${package_cmd:?ERROR no supported program}" ] || \
    { echo "ERROR ($package_cmd) not executable"; exit 1; }


function _command() {
  case ${package_cmd##*/} in
    rpm|dpkg)	echo "--$1" ;;
    yum|apt-get) echo "$1 -y" ;;
  esac
}

cmd=`_command install`


function base() {
#  source /etc/profile.d/puppet*.sh
#
#  for m in $MODULES; do
#    sudo $SUDO_FLAGS puppet module install ${MODULE_PATH:+--modulepath $MODULE_PATH} $m
#  done

}



case $os_family in
  RedHat)
	_suffix=rpm
	;;
  Debian)
	_suffix=deb
	;;
  *)	unset _prefix
	_suffix=pkg
esac

case $layer in
  base)
    case $os_family in
	RedHat)	PACKAGES+=' libproxy'
		REPOS+=" http://dl.fedoraproject.org/pub/epel/epel-release-latest-%{os_distro}.noarch.${_suffix}"
		REPOS+=" http://yum.puppetlabs.com/puppetlabs-release-pc1-el-${os_distro}.noarch.${_suffix}"
		;;
	Debian)	PACKAGES+=' libproxy0'
		REPOS+=" http://apt.puppetlabs.com/puppetlabs-release-pc1-${os_distro}.${_suffix}"
		;;
    esac
    ;;
esac


# purge proxy settings if not properly set
for v in {http{,s},no}_proxy; do
  [ -z "${!v}" ] && unset $v
done

set -e
#set -x
for r in $REPOS; do
  sudo $SUDO_FLAGS $package_cmd $cmd $r
done

for p in $PACKAGES; do
  sudo $SUDO_FLAGS $package_cmd $cmd $p
done

# invoke $layer to finalize
[ -n `declare -F "$layer"` ] && $layer


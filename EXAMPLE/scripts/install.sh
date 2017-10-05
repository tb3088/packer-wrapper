#!/bin/bash

installer=$( set -- `which yum apt-get dpkg 2>/dev/null`; echo $1 )

[ -x "${installer:?ERROR no supported program}" ] || \
    { echo "ERROR ($installer) not executable"; exit 1; }

cmd=`basename "$0" .sh`

case $installer in
  dpkg)	cmd="--$cmd"
esac

$installer $cmd $@

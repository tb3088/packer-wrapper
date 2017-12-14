#!/bin/bash
[ "${TERM#screen}" != "$TERM" ] \
    && { echo "WARN: hitting CTRL-C to abort will wedge under Screen!"; echo; }

cmd=`basename $0 ".sh"`

# assume running in AWS
: ${CLOUD:=aws}

IAM_URL='http://169.254.169.254/latest/meta-data/iam/security-credentials/'
USING_IAM=false
CREDENTIALS=""



function usage() {
  cat <<_EOF
$0 [options] [packer_args] ... <template|layer> 

  build:
    -a	<AWS_PROFILE>
#    -k	<keystore>
    -O	<list,>	(only)
    -X	<list,>	(except)

    -1, -parallel=false
    -d, -debug
    -f, -force
    -M, -machine-readable
    -n, -noop
    -p, -on-error=ask
    -v, -verbose

  validate:
    -N, -syntax-only

  <shared>
    -i	<image>	(eg. AMI)
    -e	<environment>
#    -l	<layer>
    -r	<AWS_REGION>
    -t	<template>


  inspect:
    -M, -machine-readable

----------
    environment ::= development | qa | production
    layer   	::= base | frontend | backend | etc.
    region	::= us-east-1 | http://docs.aws.amazon.com/general/latest/gr/rande.html

https://www.packer.io/docs/command-line/build.html
_EOF
    exit 2
}

case $cmd in
# original 'h1dfmnpa:e:k:O:i:r:t:X:'
    build)
	GETOPT='h1dfMnpa:e:O:i:r:t:X:'
	;;
    validate)
	GETOPT='hNe:i:r:t:'
	;;
    inspect)
	GETOPT='hMt:'
	;;
    *)	echo "ERROR: unhandled command ($cmd)"; usage
esac

while getopts "$GETOPT" sw; do
    case ${sw} in
        1)  cmd+=' -parallel=false' ;;
        a)  eval ${CLOUD^^}_PROFILE=${OPTARG} ;;
        d)  cmd+=' -debug'; DEBUG+=1 ;;
        e)  ENV=${OPTARG} ;;
        f)  cmd+=' -force' ;;
        i)  IMAGE=${OPTARG} ;;
#        k)  KEYSTORE=${OPTARG} ;;
#        l)  LAYER=$OPTARG ;;
        M)  cmd+=' -machine-readable' ;;
        n)  cmd+=' -var noop=true' ;;
        N)  cmd+=' -syntax-only' ;;
        O)  cmd+=" -only=$OPTARG" ;;
        p)  cmd+=' -on-error=ask' ;;
        r)  eval ${CLOUD^^}_REGION=${OPTARG} ;;
	t)  [ -r "${OPTARG}" ] && TEMPLATE="${OPTARG}" || \
		echo "WARN: template ($OPTARG) not found" ;;
        X)  cmd+=" -except=${OPTARG}" ;;
	h)  usage ;;
#	*)  echo "NOTICE: invalid switch ($sw) or missing arg"
    esac
done
shift $((OPTIND-1))

[ -z "$TEMPLATE" -a ${#@} -eq 0 ] && { echo "ERROR: insufficient args"; usage; }


# set some useful defaults
#
: ${BUILD_NUMBER:=`date "+%F.%H%M"`}
#TODO use indirect reference
# eval : \$\{${CLOUD^^}_PROFILE:=\$${CLOUD^^}_DEFAULT_PROFILE\}

case ${CLOUD,,} in
  aws)
	: ${AWS_PROFILE:=$AWS_DEFAULT_PROFILE}
	: ${AWS_REGION:=$AWS_DEFAULT_REGION}
	;;
esac

case "${ENV:=production}" in
    dev*)
	ENV=development
	;;
    qa)	;;
    prod*)
	ENV=production
	;;

    *)	echo "ERROR: unknown environment ($ENV)"
	usage
esac


#if [ "$cmd" = "build" ]; then
# XXX detect if we're inside AWS
#  IAM_PROFILE=$( curl -fs -m 10 --retry 3 "IAM_URL" ) || true
#  if [ -n "${IAM_PROFILE}" ] ; then
#    CREDENTIALS=$( curl -fs -m 15 --retry 3 "$IAM_URL/${IAM_PROFILE}" ) || true
#  fi
#
#  if [ -n "$CREDENTIALS" ]; then
#    #TODO set temporary creds into environment?
#    USING_IAM=true
#  fi
#fi


# pick up any var-files
# variable precedence is LAST match
#
#TODO indirect expansion of $CLOUD_*

for path in project `eval echo ${ENV:+\{env/,\}$ENV} ${IMAGE:+\{image/,\}$IMAGE} \
	${LAYER:+\{layer/,\}$LAYER} \
	${AWS_PROFILE:+${CLOUD,,}/profile/$AWS_PROFILE} \
	${AWS_REGION:+${CLOUD,,}/region/$AWS_REGION}` ; do

  for suffix in '' .var .json ; do
    [ -f "${path}${suffix}" ] && { cmd+=" -var-file=${path}${suffix}"; break; }
  done
done


for v in CLOUD DEBUG; do
  [ -n "${!v}" ] && cmd+=" -var ${v,,}=${!v}"
done


PACKER_NO_COLOR=true
[ ${DEBUG:-0} -gt 1 ] && PACKER_LOG=1

export ${!PACKER_*} ${!AWS_*} BUILD_NUMBER

# 'inspect' mode, discard all command args
[ "${cmd/% *}" = 'inspect' ] && cmd='inspect'

#umask 077; is ignored by -debug when dropping temporary SSH private key
set -x
packer $cmd $@ $TEMPLATE


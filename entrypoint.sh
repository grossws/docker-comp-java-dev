#!/bin/bash

log() {
  local LEVEL=INFO
  if [ $# -eq 2 ] ; then
    LEVEL=$1
    shift
  fi

  local MSG=$1

  echo "[$LEVEL]: $MSG" 1>&2
}

nearest() {
  local TARGET=$1

  local NEAREST_URL="http://www.apache.org/dyn/closer.cgi/${TARGET}?asjson=1"
  curl -sSL $NEAREST_URL \
    | awk '/"path_info": / { pi=$2; }; /"preferred":/ { pref=$2; }; END { print pref " " pi; };' \
    | sed -r -e 's/^"//; s/",$//; s/" "//'
}

import_gpg_keys() {
  local GPG_DIR=$1
  local KEYS=$2

  mkdir -p $GPG_DIR
  chmod 0700 $GPG_DIR

  local -a FPRS=( $(cat ${KEYS} | gpg --with-fingerprint --with-colons | grep fpr | cut -d: -f10) )
  log INFO "fetching ${#FPRS[*]} gpg keys"
  gpg --homedir $GPG_DIR --keyserver hkp://keys.gnupg.net --recv-keys ${FPRS[*]}
}

remote_exists() {
  local url=$1
  curl --fail --head --location $url &> /dev/null
  local st=$?
  if [ $st -eq 0 ] ; then
    echo 1
  elif [ $st -eq 22 ] ; then
    echo 0
  else
    log ERR "unexpected curl exit code $st when checking $url"
    exit 1
  fi
}

remote_try_fetch() {
  local TARGET=$1
  shift

  for URL in "$@" ; do
    if [ $(remote_exists ${URL}) = "1" ] ; then
      curl --location --silent --show-error --output ${TARGET} ${URL}
      return
    fi
  done

  log ERR "can't fetch ${TARGET} from $@"
  exit 1
}

fetch_tool() {
  if [ $# -lt 4 ] ; then
    log ERR "usage: fetch TARGET BASE_PATH KEYS_PATH DIST_PATH [ext]"
    log ERR "example: fetch maven maven/ KEYS maven-3/binaries/apache-maven-3.3.9-bin tar.gz"
    log ERR "example: fetch maven maven/ KEYS maven-3/binaries/apache-maven-3.3.9-bin"
    exit 1
  fi

  local TARGET=$1
  local BASE_PATH=$2
  local KEYS_PATH=$3
  local TARGET_PATH=$4
  local TARGET_EXT=${5:-tar.gz}

  local DIST_DIR=/tmp/${TARGET}-dist
  local GPG_DIR=$DIST_DIR/gpg
  local TARGET_DIR=/opt/${TARGET}

  local BASE_URL="https://www.apache.org/dist/"
  local ARCHIVE_URL="https://archive.apache.org/dist/"

  log INFO "installing ${TARGET}"

  # prepare dirs

  mkdir -p $DIST_DIR
  mkdir -p $TARGET_DIR


  pushd $DIST_DIR &> /dev/null


  # import gpg keys
  local KEYS_FULL_PATH="${BASE_PATH}${KEYS_PATH}"
  local KEYS_URL="${BASE_URL}${KEYS_FULL_PATH}"
  local ARCHIVE_KEYS_URL="${ARCHIVE_URL}${KEYS_FULL_PATH}"
  local KEYS_FILE="${DIST_DIR}/KEYS"
  remote_try_fetch "${KEYS_FILE}" "${KEYS_URL}" "${ARCHIVE_KEYS_URL}"
  import_gpg_keys "${GPG_DIR}" "${KEYS_FILE}"


  log INFO "fetching archives"
  # fetching archive and signature
  local TARGET_FULL_PATH="${BASE_PATH}${TARGET_PATH}.${TARGET_EXT}"
  local MIRROR_TARGET_URL="$(nearest ${TARGET_FULL_PATH})"
  local TARGET_URL="${BASE_URL}${TARGET_FULL_PATH}"
  local ARCHIVE_TARGET_URL="${ARCHIVE_URL}${TARGET_FULL_PATH}"
  local TARGET_FILE="${DIST_DIR}/${TARGET}.${TARGET_EXT}"

  remote_try_fetch "${TARGET_FILE}" "${MIRROR_TARGET_URL}" "${TARGET_URL}" "${ARCHIVE_TARGET_URL}"
  remote_try_fetch "${TARGET_FILE}.asc" "${MIRROR_TARGET_URL}.asc" "${TARGET_URL}.asc" "${ARCHIVE_TARGET_URL}.asc"

  log INFO "verifing gpg signatures"
  gpg --homedir $GPG_DIR --verify ${TARGET_FILE}.asc ${TARGET_FILE}

  log INFO "unpacking dist"
  tar -xf ${TARGET_FILE} --strip-components=1 --directory ${TARGET_DIR}

  popd &> /dev/null
}

cleanup_tools() {
  for TOOL in "$@" ; do
    rm -rf /tmp/${TOOL}-dist
  done
}

if [ "$1" = "bootstrap-tools" ] ; then
  MVN_VERSION=3.5.0
  ANT_VERSION=1.10.1
  #IVY_VERSION=2.4.0

  fetch_tool maven maven/ KEYS maven-${MVN_VERSION%%.*}/${MVN_VERSION}/binaries/apache-maven-${MVN_VERSION}-bin tar.gz
  fetch_tool ant ant/ KEYS binaries/apache-ant-${ANT_VERSION}-bin tar.gz
  #fetch_tool ivy ant/ KEYS ivy/${IVY_VERSION}/apache-ivy-${IVY_VERSION}-bin-with-deps tar.gz

  log INFO "updating alternatives"

  alternatives --install /usr/bin/mvn mvn /opt/maven/bin/mvn 100
  alternatives --install /usr/bin/ant ant /opt/ant/bin/ant 100

  log INFO "finished"

  exit 0
elif [ "$1" = "cleanup-tools" ] ; then
  cleanup_tools maven ant
  exit 0
fi

exec gosu dev:users /bin/bash -l -c "$@"

# vim: sw=2:sts=2:et:

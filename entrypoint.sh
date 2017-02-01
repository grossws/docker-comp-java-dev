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

  TARGET=$1
  BASE_PATH=$2
  KEYS_PATH=$3
  TARGET_PATH=$4
  TARGET_EXT=${5:-tar.gz}

  DIST_DIR=/tmp/${TARGET}-dist
  GPG_DIR=$DIST_DIR/gpg
  TARGET_DIR=/opt/${TARGET}

  BASE_URL="https://www.apache.org/dist/"
  ARCHIVE_URL="https://archive.apache.org/dist/"

  log INFO "installing ${TARGET}"

  # prepare dirs

  mkdir -p $DIST_DIR
  mkdir -p $TARGET_DIR


  pushd $DIST_DIR &> /dev/null


  # import gpg keys
  KEYS_FULL_PATH="${BASE_PATH}${KEYS_PATH}"
  KEYS_URL="${BASE_URL}${KEYS_FULL_PATH}"
  ARCHIVE_KEYS_URL="${ARCHIVE_URL}${KEYS_FULL_PATH}"
  KEYS_FILE="${DIST_DIR}/KEYS"
  remote_try_fetch "${KEYS_FILE}" "${KEYS_URL}" "${ARCHIVE_KEYS_URL}"
  import_gpg_keys "${GPG_DIR}" "${KEYS_FILE}"


  log INFO "fetching archives"
  # fetching archive and signature
  TARGET_FULL_PATH="${BASE_PATH}${TARGET_PATH}.${TARGET_EXT}"
  MIRROR_TARGET_URL="$(nearest ${TARGET_FULL_PATH})"
  TARGET_URL="${BASE_URL}${TARGET_FULL_PATH}"
  ARCHIVE_TARGET_URL="${ARCHIVE_URL}${TARGET_FULL_PATH}"
  TARGET_FILE="${DIST_DIR}/${TARGET}.${TARGET_EXT}"

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
  MVN_VERSION=3.3.9
  ANT_VERSION=1.10.0
  #IVY_VERSION=2.4.0

  fetch_tool maven maven/ KEYS maven-${MVN_VERSION%%.*}/${MVN_VERSION}/binaries/apache-maven-${MVN_VERSION}-bin tar.gz
  fetch_tool ant ant/ KEYS binaries/apache-ant-${ANT_VERSION}-bin tar.gz
  #fetch_tool ivy ant/ KEYS ivy/${IVY_VERSION}/apache-ivy-${IVY_VERSION}-bin-with-deps tar.gz

  TOOLS_EXPORTS=/etc/profile.d/java-tools.sh
  log INFO "writing exports to $TOOLS_EXPORTS"

  cat <<-EOF > $TOOLS_EXPORTS
export MVN_HOME=/opt/maven
export ANT_HOME=/opt/ant

export PATH=\$ANT_HOME/bin:\$MVN_HOME/bin:\$PATH
EOF

  chmod +x $TOOLS_EXPORTS

  log INFO "finished"

  exit 0
elif [ "$1" = "cleanup-tools" ] ; then
  cleanup_tools maven ant
  exit 0
fi

exec gosu dev:users /bin/bash -l -c "$@"

# vim: sw=2:sts=2:et:

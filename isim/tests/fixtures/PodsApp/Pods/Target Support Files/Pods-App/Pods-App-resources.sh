#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

install_resource()
{
  echo "$RESOURCE_PATH" || true
  echo "${PODS_ROOT}/$1" >> "$RESOURCES_TO_COPY"
}
if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/StaticPod/StaticPodResources.bundle"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/StaticPod/StaticPodResources.bundle"
fi
rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
rm -f "$RESOURCES_TO_COPY"

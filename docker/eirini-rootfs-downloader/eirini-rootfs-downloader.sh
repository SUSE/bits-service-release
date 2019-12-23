#!/bin/bash -ex

ASSETS_PATH="/assets"

function main
{
    abort_if_eirini_rootfs_version_not_set

    abort_if_rootfs_version_does_not_exist

    create_version_file_if_non_existent

    sync_and_download_rootfs_tar_version
}

function sync_and_download_rootfs_tar_version
{

    if [ ! -s ${ASSETS_PATH}/eirini_rootfs_version_file ]; then
        echo "INFO: EIRINI_ROOTFS_VERSION specified - will download version ($EIRINI_ROOTFS_VERSION) of rootfs from GitHub"
        download_rootfs_tar
        persist_version
        echo "INFO: EIRINI_ROOTFS_VERSION ($EIRINI_ROOTFS_VERSION) successfully downloaded - exiting."
        return 0
    else
        is_specified_rootfs_version_present
        echo "INFO: RootFS is outdated - Downloading..."
        delete_eirini_rootfs_tar_if_present
        download_rootfs_tar
        persist_version
        echo "INFO: EIRINI_ROOTFS_VERSION ($EIRINI_ROOTFS_VERSION) successfully downloaded - exiting."
        return 0
    fi
}

function abort_if_eirini_rootfs_version_not_set
{
    if [[ -z "${EIRINI_ROOTFS_VERSION}" ]]; then
        echo "ERROR: EIRINI_ROOTFS_VERSION is not specified - aborting."
        return 1
    fi
}

function create_version_file_if_non_existent
{
    if [ ! -f ${ASSETS_PATH}/eirini_rootfs_version_file ]; then
        touch ${ASSETS_PATH}/eirini_rootfs_version_file
    fi
}

function persist_version
{
    echo $EIRINI_ROOTFS_VERSION > ${ASSETS_PATH}/eirini_rootfs_version_file
}

function download_rootfs_tar
{
    local api_data eirinifs_url eirinifs_sha256_url checksum
    local sha256_file="${ASSETS_PATH}/eirinifs.tar.${EIRINI_ROOTFS_VERSION}.sha256"
    local tmp_file="${ASSETS_PATH}/eirinifs.tar.${EIRINI_ROOTFS_VERSION}.downloading"

    api_data=$(curl -sS "https://api.github.com/repos/cloudfoundry-incubator/eirinifs/releases/tags/${EIRINI_ROOTFS_VERSION}")
    eirinifs_url=$(jq -r <<< "$api_data" '.assets[] | select(.name == "eirinifs.tar") | .browser_download_url')
    eirinifs_sha256_url=$(jq -r <<< "$api_data" '.assets[] | select(.name == "eirinifs.tar.sha256") | .browser_download_url')

    curl -Ss -L "$eirinifs_sha256_url" --output "$sha256_file"
    curl -C- -L "$eirinifs_url" --output "$tmp_file"

    checksum=$(sha256sum -b "$tmp_file" | cut -d' ' -f1)

    if [ "$checksum" != "$(cat "$sha256_file")" ]; then
        echo "ERROR: Checksum doesn't match. Deleting $tmp_file and exiting ..."
        rm "$tmp_file"
        exit 1
    fi

    mv "$tmp_file" "${ASSETS_PATH}/eirinifs.tar"
}

function is_specified_rootfs_version_present
{
    LOCAL_version=$(cat ${ASSETS_PATH}/eirini_rootfs_version_file)
    REMOTE_version=${EIRINI_ROOTFS_VERSION}
    if [ "$LOCAL_version" == "$REMOTE_version" ]
     then
        echo "INFO: Already have the downloaded version ${EIRINI_ROOTFS_VERSION} "
        exit 0
    else
        echo "INFO: Specified version is not there, need to download"
    fi
}

function abort_if_rootfs_version_does_not_exist 
{
    STATUS_CODE=$(curl -I -L https://api.github.com/repos/cloudfoundry-incubator/eirinifs/releases/tags/${EIRINI_ROOTFS_VERSION} --write-out  %{http_code} --silent --output /dev/null)
    if [ "$STATUS_CODE" == "200" ]
    then
        echo "INFO: The specified rootfs version (${EIRINI_ROOTFS_VERSION}) exists --continue"
    elif [ "$STATUS_CODE" == "404" ]
     then
        echo "ERROR: The specified rootfs version (${EIRINI_ROOTFS_VERSION}) does not exist - please speficy an existing version"
        exit 1
    else
        echo "ERROR: Unexpected server response code : {STATUS_CODE} - aborting"
        exit 1
    fi
}

function delete_eirini_rootfs_tar_if_present
{
    if [ -f ${ASSETS_PATH}/eirinifs.tar ]; then
        echo "Found outdated RootFS - deleting it"
        rm -rf ${ASSETS_PATH}/eirinifs.tar
    fi
}
main

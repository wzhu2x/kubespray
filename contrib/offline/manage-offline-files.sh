#!/bin/bash

CURRENT_DIR=$( dirname "$(readlink -f "$0")" )
OFFLINE_FILES_DIR_NAME="offline-files"
OFFLINE_FILES_DIR="${CURRENT_DIR}/${OFFLINE_FILES_DIR_NAME}"
OFFLINE_FILES_ARCHIVE="${CURRENT_DIR}/offline-files.tar.gz"
FILES_LIST=${FILES_LIST:-"${CURRENT_DIR}/temp/files.list"}
NGINX_PORT=8080

# check parameter
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 {download|nginx}"
    exit 1
fi

# check FILES_LIST exist
if [ ! -f "${FILES_LIST}" ]; then
    echo "${FILES_LIST} should exist ./generate_list.sh."
    exit 1
fi

download_files() {
    # If the offline file directory does not exist or is empty, download the file
    if [ ! -d "${OFFLINE_FILES_DIR}" ] || [ -z "$(ls -A "${OFFLINE_FILES_DIR}")" ]; then
        rm -rf "${OFFLINE_FILES_DIR}"
        mkdir "${OFFLINE_FILES_DIR}"

        while read -r url; do
          if ! wget -x -P "${OFFLINE_FILES_DIR}" "${url}"; then
            exit 1
          fi
        done < "${FILES_LIST}"

        tar -czvf "${OFFLINE_FILES_ARCHIVE}" -C "${CURRENT_DIR}" "${OFFLINE_FILES_DIR_NAME}"
    else
        echo "offline file is exist,skipping download..."
    fi
}

run_nginx() {

    if command -v nerdctl 1>/dev/null 2>&1; then
        runtime="nerdctl"
    elif command -v podman 1>/dev/null 2>&1; then
        runtime="podman"
    elif command -v docker 1>/dev/null 2>&1; then
        runtime="docker"
    else
        echo "No supported container runtime found"
        exit 1
    fi

    # setup nginx container
    sudo "${runtime}" container inspect nginx >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        sudo "${runtime}" run \
            --restart=always -d -p ${NGINX_PORT}:80 \
            --volume "${OFFLINE_FILES_DIR}":/usr/share/nginx/html/download \
            --volume "${CURRENT_DIR}/nginx.conf":/etc/nginx/nginx.conf \
            --name nginx docker.io/library/nginx:1.25.2-alpine
    fi
}

case "$1" in
    download)
        download_files
        ;;
    nginx)
        run_nginx
        ;;
    *)
        echo "Invalid parameter: $1"
        echo "Usage: $0 {download|nginx}"
        exit 1
        ;;
esac
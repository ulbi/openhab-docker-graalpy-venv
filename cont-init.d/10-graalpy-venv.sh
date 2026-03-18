#!/bin/bash

VENV_LINK="/openhab/userdata/cache/org.openhab.automation.pythonscripting/venv"
PREBUILT_VENV="/openhab/python/venv"

if [ -d "${PREBUILT_VENV}" ]; then
    echo "Linking pre-built venv to ${VENV_LINK}"
    mkdir -p "$(dirname "${VENV_LINK}")"
    chown -R 9001:9001 /openhab/userdata/cache
    ln -sfn "${PREBUILT_VENV}" "${VENV_LINK}"
else
    echo "Warning: pre-built venv not found at ${PREBUILT_VENV}"
fi

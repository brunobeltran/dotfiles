#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    MINICONDA_INSTALLER_LINK=https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
else
    MINICONDA_INSTALLER_LINK=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
fi

TMP_INSTALLER="/tmp/$(basename $MINICONDA_INSTALLER_LINK)"

curl $MINICONDA_INSTALLER_LINK --output "${TMP_INSTALLER}" \
    && bash "${TMP_INSTALLER}"
rm "${TMP_INSTALLER}"

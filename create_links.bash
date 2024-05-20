#!/usr/bin/env bash

set -Eeo pipefail

mkdir -pv os-dependent/{alt_p9,centos{6,7,8},rhel{6,7,8},ubuntu{18,22}.04}
for i in 6 8
do
    cd "os-dependent/rhel${i}"
    for file in ../rhel7/*
    do
        if [[ ! -e "${file##*/}" ]]
        then
            if [[ "${1}" = "prod" ]]
            then
                cp -v "${file}" "${file##*/}"
            else
                ln -vfs "${file}" "${file##*/}"
            fi
        fi
    done
    cd ../..
done

for i in 6 7 8
do
    cd "os-dependent/centos${i}"
    for file in ../rhel"${i}"/*
    do
        if [[ ! -e "${file##*/}" ]]
        then
            if [[ "${1}" = "prod" ]]
            then
                cp -v "${file}" "${file##*/}"
            else
                ln -vfs "${file}" "${file##*/}"
            fi
        fi
    done
    cd ../..
done

cd os-dependent/ubuntu22.04
for file in ../ubuntu18.04/*
do
    if [[ ! -e "${file##*/}" ]]
    then
        if [[ "${1}" = "prod" ]]
        then
            cp -v "${file}" "${file##*/}"
        else
            ln -vfs "${file}" "${file##*/}"
        fi
    fi
done
cd ../..

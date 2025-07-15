#!/usr/bin/env bash
set -e

rm -rf ./out
docker buildx build --progress=plain --platform=linux/arm64 --pull --build-arg BASE_IMAGE=rockylinux/rockylinux:9 --build-arg OS_ARCH=arm64 --build-arg TOOLCHAIN_ARCH=aarch64 -t containerd:arm64 .
docker cp $(docker create --rm containerd:arm64):/out ./
ls -lah ./out/

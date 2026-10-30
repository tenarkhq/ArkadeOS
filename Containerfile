# ArkadeOS image. One Containerfile builds every variant; the build workflow
# passes the Bazzite base image and the ArkadeOS image name.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY cosign.pub /cosign.pub

FROM ${BASE_IMAGE}

ARG IMAGE_NAME=arkadeos
ARG IMAGE_VENDOR=tenarkhq
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

RUN bootc container lint

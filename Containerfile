# ArkadeOS image. One Containerfile builds every variant; the build workflow
# passes the Bazzite base image and the ArkadeOS image name.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY cosign.pub /cosign.pub

FROM ${BASE_IMAGE}

# Proton-GE gets its own layer before everything else, so the build server's
# layer cache reuses it until a new GE-Proton release comes out.
ARG PROTON_GE_VERSION
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/proton-ge.sh "${PROTON_GE_VERSION}"

# WhiteSur theme files (T006), pinned upstream commits; cached the same way.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/whitesur.sh

ARG IMAGE_NAME=arkadeos
ARG IMAGE_VENDOR=tenarkhq
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

RUN bootc container lint

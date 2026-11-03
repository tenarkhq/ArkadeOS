# ArkadeOS image. One image for every graphics card (T080); the build workflow
# passes the Bazzite base image (bases.txt) and the ArkadeOS image name.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable

# The build files. Each step below sees only the files it uses, so the build
# server's layer cache keeps a step until those files change (T081): a change
# to ArkadeOS's own files rebuilds only the last step, in a few minutes.
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY cosign.pub /cosign.pub

FROM scratch AS ctx-solid
COPY build_files/solid.sh /solid.sh
COPY build_files/patches /patches

FROM scratch AS ctx-packages
COPY build_files/packages /packages
COPY system_files/etc/pki/arkadeos/arkadeos-mok.der /packages/arkadeos-mok.der

FROM scratch AS ctx-whitesur
COPY build_files/whitesur.sh /whitesur.sh

FROM scratch AS ctx-proton
COPY build_files/proton-ge.sh /proton-ge.sh

# Solid with ArkadeOS's patch (T069), built from the base's own source package
# in a throwaway stage; only the packages go into the image.
FROM ${BASE_IMAGE} AS solid
RUN --mount=type=bind,from=ctx-solid,source=/,target=/ctx \
    /ctx/solid.sh /solid

FROM ${BASE_IMAGE}

# Packages: rebuilt when the base or packages/ changes.
RUN --mount=type=bind,from=ctx-packages,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok,required=false \
    --mount=type=bind,from=solid,source=/solid,target=/solid \
    /ctx/packages/install.sh

# WhiteSur theme files (T006), pinned upstream commits.
RUN --mount=type=bind,from=ctx-whitesur,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/whitesur.sh

# Proton-GE: rebuilt with each GE-Proton release.
ARG PROTON_GE_VERSION
RUN --mount=type=bind,from=ctx-proton,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/proton-ge.sh "${PROTON_GE_VERSION}"

ARG IMAGE_NAME=arkadeos
ARG IMAGE_VENDOR=tenarkhq
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

RUN bootc container lint

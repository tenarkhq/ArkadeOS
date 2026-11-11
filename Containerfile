# ArkadeOS image. One image for every graphics card (T080); the build workflow
# passes the Bazzite base image (bases.txt) and the ArkadeOS image name.
#
# Its layers, on top of the base's own (T076): packages, Proton-GE, the
# initramfs, then ArkadeOS's own files. A machine downloads only the layers
# that changed, so an update that changes ArkadeOS's files brings the last,
# small one. Proton-GE and the initramfs are made in side stages and come out
# the same bytes at every build (build_files/stage.sh), also when the base or
# the packages under them changed.
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

FROM scratch AS ctx-proton
COPY build_files/proton-ge.sh build_files/stage.sh /

# What goes into the initramfs besides the packages: the boot screen.
FROM scratch AS ctx-boot
COPY build_files/initramfs.sh build_files/stage.sh build_files/os-release.sh /
COPY system_files/usr/share/plymouth /system_files/usr/share/plymouth

# Solid with ArkadeOS's patch (T069), built from the base's own source package
# in a throwaway stage; only the packages go into the image.
FROM ${BASE_IMAGE} AS solid
RUN --mount=type=bind,from=ctx-solid,source=/,target=/ctx \
    /ctx/solid.sh /solid

# Proton-GE: made again with each GE-Proton release.
FROM ${BASE_IMAGE} AS proton
ARG PROTON_GE_VERSION
RUN --mount=type=bind,from=ctx-proton,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/proton-ge.sh "${PROTON_GE_VERSION}" /out

# Packages: rebuilt when the base or packages/ changes.
FROM ${BASE_IMAGE} AS packages
RUN --mount=type=bind,from=ctx-packages,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok,required=false \
    --mount=type=bind,from=solid,source=/solid,target=/solid \
    /ctx/packages/install.sh

# The initramfs: made again when the packages or the boot screen change.
FROM packages AS initramfs
RUN --mount=type=bind,from=ctx-boot,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/initramfs.sh /out

FROM packages
COPY --from=proton /out/ /
COPY --from=initramfs /out/ /

ARG IMAGE_NAME=arkadeos
ARG IMAGE_VENDOR=tenarkhq
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

RUN bootc container lint

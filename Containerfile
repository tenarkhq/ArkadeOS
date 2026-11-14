# ArkadeOS image. One image for every graphics card (T080); the build workflow
# passes the Bazzite base image (bases.txt) and the ArkadeOS image name.
#
# Its layers, on top of the base's own (T076): packages, Proton-GE, the
# initramfs, then ArkadeOS's own files. A machine downloads only the layers
# that changed, so an update that changes ArkadeOS's files brings the last,
# small one. Proton-GE and the initramfs are made in side stages and come out
# the same bytes at every build (build_files/stage.sh), also when the base or
# the packages under them changed.
#
# Each step mounts just the files it uses, straight from the repository
# (T081). The build tool puts a checksum of what a step mounts into that
# step's name in its layer cache, so a step is built again exactly when one
# of its files changed, and a change to ArkadeOS's own files rebuilds only
# the last step, in a few minutes. The files must not come through a build
# stage of their own (FROM scratch, COPY, then --mount from=that stage): a
# mount from a stage carries no checksum, and a step whose files changed was
# then taken from the cache as it was built for another base or before a
# revert. A step that uses another stage's result mounts that stage's files
# too, so it changes with them.
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable

# Solid with ArkadeOS's patch (T069), built from the base's own source package
# in a throwaway stage; only the packages go into the image.
FROM ${BASE_IMAGE} AS solid
RUN --mount=type=bind,source=build_files/solid.sh,target=/ctx/solid.sh \
    --mount=type=bind,source=build_files/patches,target=/ctx/patches \
    /ctx/solid.sh /solid

# Proton-GE: made again with each GE-Proton release.
FROM ${BASE_IMAGE} AS proton
ARG PROTON_GE_VERSION
RUN --mount=type=bind,source=build_files/proton-ge.sh,target=/ctx/proton-ge.sh \
    --mount=type=bind,source=build_files/stage.sh,target=/ctx/stage.sh \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/proton-ge.sh "${PROTON_GE_VERSION}" /out

# Packages: rebuilt when the base or packages/ changes (or Solid's patch, whose
# packages it installs).
FROM ${BASE_IMAGE} AS packages
RUN --mount=type=bind,source=build_files/packages,target=/ctx/packages \
    --mount=type=bind,source=system_files/etc/pki/arkadeos/arkadeos-mok.der,target=/ctx/arkadeos-mok.der \
    --mount=type=bind,source=build_files/solid.sh,target=/ctx/solid.sh \
    --mount=type=bind,source=build_files/patches,target=/ctx/patches \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok,required=false \
    --mount=type=bind,from=solid,source=/solid,target=/solid \
    /ctx/packages/install.sh

# The initramfs: made again when the packages or the boot screen change. What
# goes into it besides the packages is mounted here: the boot screen.
FROM packages AS initramfs
RUN --mount=type=bind,source=build_files/initramfs.sh,target=/ctx/initramfs.sh \
    --mount=type=bind,source=build_files/stage.sh,target=/ctx/stage.sh \
    --mount=type=bind,source=build_files/os-release.sh,target=/ctx/os-release.sh \
    --mount=type=bind,source=system_files/usr/share/plymouth,target=/ctx/system_files/usr/share/plymouth \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/initramfs.sh /out

# Better Blur DX (T086): built for the image's own KWin, so it comes after the
# packages; only its two plugins leave the stage.
FROM packages AS blur
RUN --mount=type=bind,source=build_files/better-blur.sh,target=/ctx/better-blur.sh \
    --mount=type=bind,source=build_files/stage.sh,target=/ctx/stage.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/better-blur.sh /out

# Darkly (T086): the widget style of ArkadeOS Glass windows, built for the
# image's own Qt and Frameworks; only the style and its settings page leave
# the stage.
FROM packages AS darkly
RUN --mount=type=bind,source=build_files/darkly.sh,target=/ctx/darkly.sh \
    --mount=type=bind,source=build_files/stage.sh,target=/ctx/stage.sh \
    --mount=type=cache,dst=/var/cache \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/darkly.sh /out

FROM packages
COPY --from=proton /out/ /
COPY --from=initramfs /out/ /
COPY --from=blur /out/ /
COPY --from=darkly /out/ /

ARG IMAGE_NAME=arkadeos
ARG IMAGE_VENDOR=tenarkhq
ARG IMAGE_VERSION=dev

RUN --mount=type=bind,source=build_files,target=/ctx/build_files \
    --mount=type=bind,source=system_files,target=/ctx/system_files \
    --mount=type=bind,source=cosign.pub,target=/ctx/cosign.pub \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

RUN bootc container lint

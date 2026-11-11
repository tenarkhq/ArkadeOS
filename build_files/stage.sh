# Sourced by the build's side stages (proton-ge.sh, initramfs.sh). Each makes
# a piece of the image under ${out}, which the Containerfile copies in as a
# layer of its own (T076). settle gives that layer the same bytes at every
# build, so a machine downloads it once and not again with every update:
# every date is fixed, and a directory the image already has keeps the
# image's own mode and owner (COPY --from writes the stage's directory
# entries over the image's).
settle() {
    local d real
    while IFS= read -r -d '' d; do
        real=/${d#"${out}"/}
        if [[ -d "${real}" ]]; then
            chmod --reference="${real}" "${d}"
            chown --reference="${real}" "${d}"
        fi
    done < <(find "${out}" -mindepth 1 -type d -print0)
    find "${out}" -depth -exec touch -h -d @0 {} +
}

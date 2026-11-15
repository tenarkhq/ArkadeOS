# Roland, 2026-11-15: the laptop came up in Akku on the charger at every login
# ("még mindig akku energiaprofillal indul a gép"). His Plasma power settings
# said "on the charger: switch to Power Save" ([AC][Performance] PowerProfile=
# power-saver in powerdevilrc). PowerDevil applies it at every login and
# every plug-in, after the ArkadeOS check at boot (power-ac) has run. On the
# charger the ArkadeOS profiles decide (Balanced, Gaming, Max), so the
# setting goes. This login's PowerDevil has already applied it: the profile
# goes back to Balanced once, unless a game holds Akku.
f="${cfg}/powerdevilrc"
[[ "$(kreadconfig6 --file "${f}" --group AC --group Performance --key PowerProfile)" == power-saver ]] || exit 0
kwriteconfig6 --file "${f}" --group AC --group Performance --key PowerProfile --delete
for _ in $(seq 10); do
    sleep 2
    [[ "$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null)" == "b false" ]] || exit 0
    ppd=$(busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles \
        ActiveProfile ActiveProfileHolds 2>/dev/null) || continue
    { read -r _ active; read -r _ holds _; } <<< "${ppd}"
    if [[ "${active//\"/}" == power-saver && "${holds}" == 0 ]]; then
        /usr/bin/arkadeos-power set balanced >/dev/null 2>&1 || true
        exit 0
    fi
done
exit 0

/*
 * Tells the power profile switch when to read the profile again (T050): the
 * power profile service says so when the profile or a game's hold on it
 * changes, UPower when the charger goes in or out. The switch loads this file
 * by itself and works without it, so a Plasma without this D-Bus module only
 * makes it look more often.
 */
import QtQuick
import org.kde.plasma.workspace.dbus as DBus

Item {
    id: watch

    signal changed()

    DBus.Properties {
        busType: DBus.BusType.System
        service: "net.hadess.PowerProfiles"
        path: "/net/hadess/PowerProfiles"
        iface: "net.hadess.PowerProfiles"
        onPropertiesChanged: watch.changed()
    }
    DBus.Properties {
        busType: DBus.BusType.System
        service: "org.freedesktop.UPower"
        path: "/org/freedesktop/UPower"
        iface: "org.freedesktop.UPower"
        onPropertiesChanged: watch.changed()
    }
}

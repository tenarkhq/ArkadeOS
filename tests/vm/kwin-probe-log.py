#!/usr/bin/python3
"""VM test only: a session bus service that writes the lines of the KWin probe
(kwin-probe.js) to a file; KWin keeps a script's print() out of the journal.
    kwin-probe-log.py <file>"""
import sys

from gi.repository import Gio, GLib

XML = ("<node><interface name='org.arkadeos.Probe'><method name='Log'>"
       "<arg type='s' direction='in'/></method></interface></node>")
out = open(sys.argv[1], "a", buffering=1)


def call(conn, sender, path, iface, method, params, invocation):
    out.write(params.unpack()[0] + "\n")
    invocation.return_value(None)


def bus(conn, name):
    conn.register_object("/", Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], call, None, None)


Gio.bus_own_name(Gio.BusType.SESSION, "org.arkadeos.Probe", Gio.BusNameOwnerFlags.NONE, bus, None, None)
GLib.MainLoop().run()

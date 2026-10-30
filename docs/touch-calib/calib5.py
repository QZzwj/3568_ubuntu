#!/usr/bin/env python3
# 5 点触屏校准采集（纯 Gtk 控件，不依赖 pycairo）
import sys, os
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk

OUT = "/tmp/cal.txt"
TARGETS = [(34, 34), (1246, 34), (34, 686), (1246, 686), (640, 360)]
R = 26

CSS = b"""
window#calwin { background-color: #ffffff; }
#caldot { background-color: #1246FF; border-radius: 26px; }
#caltxt { color: #12233d; font-size: 15px; }
"""

class Cal(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_name("calwin")
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.set_accept_focus(True)
        self.i = 0
        self.fx = Gtk.Fixed()
        self.add(self.fx)
        prov = Gtk.CssProvider()
        prov.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(self.get_screen(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.dot = Gtk.EventBox()
        self.dot.set_name("caldot")
        self.dot.set_size_request(2 * R, 2 * R)
        self.fx.put(self.dot, 0, 0)
        self.lab = Gtk.Label()
        self.lab.set_name("caltxt")
        self.fx.put(self.lab, 0, 0)
        self.connect("button-press-event", self.on_press)
        self.connect("key-press-event", self.on_key)
        self.fullscreen()
        self.show_all()
        open(OUT, "w").write("# target_x target_y event_x event_y\n")
        self.place()
        print("ready", flush=True)

    def place(self):
        if self.i >= len(TARGETS):
            self.dot.hide()
            self.fx.move(self.lab, 520, 330)
            self.lab.set_text("DONE  -  press Esc")
            self.lab.show()
            return
        tx, ty = TARGETS[self.i]
        self.fx.move(self.dot, tx - R, ty - R)
        self.dot.show()
        self.fx.move(self.lab, max(6, tx - 60), max(6, ty - R - 30))
        self.lab.set_text("click %d / %d" % (self.i + 1, len(TARGETS)))
        self.lab.show()

    def on_key(self, w, e):
        if e.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

    def on_press(self, w, e):
        if self.i >= len(TARGETS):
            return True
        tx, ty = TARGETS[self.i]
        with open(OUT, "a") as f:
            f.write("%d %d %d %d\n" % (tx, ty, int(e.x_root), int(e.y_root)))
        print("captured", tx, ty, int(e.x_root), int(e.y_root), flush=True)
        self.i += 1
        self.place()
        return True

w = Cal()
Gtk.main()

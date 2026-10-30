#!/usr/bin/env python3
# 触屏边缘探测：红点跟随触点，实时显示收到的坐标与最大/最小值
import sys, os, time
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib

OUT = "/tmp/cal2.txt"
D = 22

CSS = b"""
window#ew { background-color: #ffffff; }
#dot { background-color: #e8322d; border-radius: 11px; }
#hud { color: #12233d; font-size: 16px; }
#hud2 { color: #1246FF; font-size: 15px; }
"""

class App(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_name("ew")
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_keep_above(True)
        self.fx = Gtk.Fixed()
        self.add(self.fx)
        p = Gtk.CssProvider(); p.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(self.get_screen(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.dot = Gtk.EventBox(); self.dot.set_name("dot"); self.dot.set_size_request(D, D)
        self.fx.put(self.dot, -100, -100)
        self.hud = Gtk.Label(); self.hud.set_name("hud"); self.fx.put(self.hud, 20, 20)
        self.hud2 = Gtk.Label(); self.hud2.set_name("hud2"); self.fx.put(self.hud2, 20, 52)
        self.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_PRESS_MASK |
                        Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.BUTTON1_MOTION_MASK)
        self.connect("motion-notify-event", self.on_motion)
        self.connect("button-press-event", self.on_press)
        self.connect("button-release-event", self.on_release)
        self.connect("key-press-event", self.on_key)
        self.fullscreen(); self.show_all()
        self.xmin = 10**9; self.xmax = -1; self.ymin = 10**9; self.ymax = -1; self.n = 0
        self.f = open(OUT, "w")
        self.f.write("# t x y down\n"); self.f.flush()
        GLib.timeout_add(700, self.flush_hud)
        print("ready", flush=True)

    def flush_hud(self):
        self.hud2.set_text("max x=%d  min x=%d   max y=%d  min y=%d   n=%d" %
                           (self.xmax, self.xmin, self.ymax, self.ymin, self.n))
        return True

    def track(self, x, y, down):
        self.n += 1
        self.xmin = min(self.xmin, x); self.xmax = max(self.xmax, x)
        self.ymin = min(self.ymin, y); self.ymax = max(self.ymax, y)
        self.f.write("%.3f %d %d %d\n" % (time.time(), x, y, down)); self.f.flush()
        self.fx.move(self.dot, x - D // 2, y - D // 2)
        self.hud.set_text("received (%d, %d)" % (x, y))

    def on_motion(self, w, e):
        self.track(int(e.x_root), int(e.y_root), 1 if (e.state & Gdk.ModifierType.BUTTON1_MASK) else 0)
        return True

    def on_press(self, w, e):
        self.track(int(e.x_root), int(e.y_root), 1)
        return True

    def on_release(self, w, e):
        self.track(int(e.x_root), int(e.y_root), 0)
        return True

    def on_key(self, w, e):
        if e.keyval == Gdk.KEY_Escape:
            self.f.write("# summary xmin=%d xmax=%d ymin=%d ymax=%d n=%d\n" % (self.xmin, self.xmax, self.ymin, self.ymax, self.n))
            self.f.flush(); Gtk.main_quit()

a = App()
Gtk.main()

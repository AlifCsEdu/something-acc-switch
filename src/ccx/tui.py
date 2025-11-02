from __future__ import annotations
import curses, os, time
from .core import list_profiles, activate_profile, read_auth_summary
from .paths import profiles_dir

B = {"tl": "╔", "tr": "╗", "bl": "╚", "br": "╝", "h": "═", "v": "║"}


class Attr:
    sel = base = dim = 0


def draw_box(stdscr, y, x, h, w, title, a):
    try:
        stdscr.addstr(y, x, B["tl"], a.dim); stdscr.addstr(y, x+w, B["tr"], a.dim)
        stdscr.addstr(y+h, x, B["bl"], a.dim); stdscr.addstr(y+h, x+w, B["br"], a.dim)
        for i in range(1, w): stdscr.addstr(y, x+i, B["h"], a.dim); stdscr.addstr(y+h, x+i, B["h"], a.dim)
        for i in range(1, h): stdscr.addstr(y+i, x, B["v"], a.dim); stdscr.addstr(y+i, x+w, B["v"], a.dim)
        if title: stdscr.addstr(y, x+2, f" {title} ")
    except: pass


def run():
    curses.wrapper(_run)


def _run(stdscr):
    curses.curs_set(0); stdscr.keypad(True)
    a = Attr(); sel = 0; status = ""
    while True:
        stdscr.erase()
        H,W = stdscr.getmaxyx()
        draw_box(stdscr, 1, 2, H-4, W-4, "ccx profiles", a)
        profs = list_profiles()
        if profs:
            sel = min(sel, len(profs)-1)
            for i,n in enumerate(profs[:H-6]):
                flag = "> " if i == sel else "  "
                stdscr.addstr(2+i, 4, f"{flag}{n}")
        if profs:
            name = profs[sel]; p = profiles_dir()/f"{name}.json"
            lines = read_auth_summary(p)
            for i,L in enumerate(lines[:H-6]):
                stdscr.addstr(2+i, W//2, L[:W-6])
        stdscr.addstr(H-2, 4, "↑/↓ move • Enter activate • q quit")
        stdscr.refresh()
        ch = stdscr.getch()
        if ch in (ord('q'), 27): return
        elif ch in (curses.KEY_UP, ord('k')): sel = (sel-1) % max(1, len(profs))
        elif ch in (curses.KEY_DOWN, ord('j')): sel = (sel+1) % max(1, len(profs))
        elif ch in (10,13) and profs:
            try:
                activate_profile(profs[sel]); status = "activated"; curses.beep()
            except Exception as e:
                status = f"error: {e}"

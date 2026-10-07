"""Generates one short looping illustration (animated WebP) per exercise in
data/exercises.csv, plus the SQL that attaches them to the exercises table.

    python scripts/generate_exercise_illustrations.py

Writes:
  public/exercises/<slug>.webp                      (served by the web portal)
  ../Inteli_Rehab_Mobile_App/assets/exercises/...   (bundled in the app, offline)
  scripts/supabase_exercise_media.sql               (adds + fills exercises.media_url)

These are simple, schematic figures - NOT clinical demonstrations. They show
the direction and region of each movement, with the target muscle in amber.
Have a physiotherapist review them, and replace any of them with a real video
by pointing exercises.media_url at the file (no code change needed).

Needs Pillow only. Colours are the apps' own theme colours.
"""
import csv
import math
import os
import re
import shutil
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # Intelli_Rehab_Web_Portal
CSV_PATH = os.path.join(ROOT, "data", "exercises.csv")
OUT_WEB = os.path.join(ROOT, "public", "exercises")
OUT_APP = os.path.join(os.path.dirname(ROOT), "Inteli_Rehab_Mobile_App", "assets", "exercises")
SQL_PATH = os.path.join(HERE, "supabase_exercise_media.sql")

W = 256          # logical canvas
S = 3            # supersampling
FRAMES = 36
FRAME_MS = 70    # 2.5 s loop

# Brand colours (the portal/app light theme)
BG = "#E4F1F0"
BODY = "#A9CBC9"
BODY_DARK = "#8DB8B6"
ARM = "#0D6E76"
ARM_FAR = "#6FA9AC"
HAND = "#0A5961"
INK = "#073C41"
AMBER = (231, 162, 76)
PROP = "#7C9A98"
WHITE = "#FFFFFF"


def rgba(c, a=255):
    if isinstance(c, tuple):
        return c[:3] + (a,)
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


def dirv(a):
    """Unit vector for an angle measured from straight DOWN, positive toward screen-right."""
    r = math.radians(a)
    return (math.sin(r), math.cos(r))


def add(p, q):
    return (p[0] + q[0], p[1] + q[1])


def mul(v, k):
    return (v[0] * k, v[1] * k)


def lerp(a, b, t):
    return a + (b - a) * t


def osc(t):
    """0 -> 1 -> 0 over the loop, smooth, with a short rest at each end."""
    x = 0.5 - 0.5 * math.cos(2 * math.pi * t)
    return x * x * (3 - 2 * x)


def ik(sh, target, l1, l2, flip=1):
    """Two-bone IK. Returns (upper_angle, fore_angle) in our angle convention."""
    dx, dy = target[0] - sh[0], target[1] - sh[1]
    d = max(min(math.hypot(dx, dy), l1 + l2 - 0.01), abs(l1 - l2) + 0.01)
    base = math.degrees(math.atan2(dx, dy))
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    a = math.degrees(math.acos(max(-1, min(1, cos_a))))
    up = base + flip * a
    e = add(sh, mul(dirv(up), l1))
    fore = math.degrees(math.atan2(target[0] - e[0], target[1] - e[1]))
    return up, fore


class Canvas:
    def __init__(self):
        self.im = Image.new("RGB", (W * S, W * S), BG)
        self.d = ImageDraw.Draw(self.im, "RGBA")

    def xy(self, p):
        return (p[0] * S, p[1] * S)

    def circ(self, c, r, col, a=255):
        x, y = self.xy(c)
        self.d.ellipse([x - r * S, y - r * S, x + r * S, y + r * S], fill=rgba(col, a))

    def ring(self, c, r, col, w=2, a=255):
        x, y = self.xy(c)
        self.d.ellipse([x - r * S, y - r * S, x + r * S, y + r * S], outline=rgba(col, a), width=int(w * S))

    def line(self, p, q, w, col, a=255, caps=True):
        self.d.line([self.xy(p), self.xy(q)], fill=rgba(col, a), width=max(1, int(w * S)))
        if caps:
            self.circ(p, w / 2, col, a)
            self.circ(q, w / 2, col, a)

    def poly(self, pts, col, a=255):
        self.d.polygon([self.xy(p) for p in pts], fill=rgba(col, a))

    def ell(self, c, rx, ry, rot, col, a=255):
        """Ellipse rotated by `rot` degrees (angle convention: 0 = long axis pointing down)."""
        pts = []
        cr, sr = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        for i in range(40):
            th = 2 * math.pi * i / 40
            x, y = rx * math.cos(th), ry * math.sin(th)
            # long axis = local y; rotate so local +y points along dirv(rot)
            pts.append((c[0] + x * cr + y * sr, c[1] - x * sr + y * cr))
        self.poly(pts, col, a)

    def rrect(self, x0, y0, x1, y1, r, col, a=255):
        self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=rgba(col, a))

    def arc(self, c, r, a0, a1, col, w=2.5, a=255):
        """Arc from angle a0 to a1 (our convention), with an arrow head at a1."""
        n = 24
        pts = []
        for i in range(n + 1):
            ang = lerp(a0, a1, i / n)
            pts.append(add(c, mul(dirv(ang), r)))
        for i in range(n):
            self.line(pts[i], pts[i + 1], w, col, a, caps=False)
        tip = pts[-1]
        back = lerp(a0, a1, 0.9)
        tang = (tip[0] - add(c, mul(dirv(back), r))[0], tip[1] - add(c, mul(dirv(back), r))[1])
        L = math.hypot(*tang) or 1
        tang = (tang[0] / L, tang[1] / L)
        nrm = (-tang[1], tang[0])
        head = [tip, add(add(tip, mul(tang, -7)), mul(nrm, 4.5)), add(add(tip, mul(tang, -7)), mul(nrm, -4.5))]
        self.poly(head, col, a)

    def arrow(self, p, q, col=INK, w=2.5, a=230):
        self.line(p, q, w, col, a, caps=False)
        v = (q[0] - p[0], q[1] - p[1])
        L = math.hypot(*v) or 1
        v = (v[0] / L, v[1] / L)
        n = (-v[1], v[0])
        self.poly([q, add(add(q, mul(v, -8)), mul(n, 5)), add(add(q, mul(v, -8)), mul(n, -5))], col, a)

    def glow(self, c, rx, ry, rot=0, strength=1.0):
        for k, f in enumerate((1.5, 1.2, 1.0)):
            self.ell(c, rx * f, ry * f, rot, AMBER, int((50 + 40 * k) * strength))

    def finish(self):
        return self.im.resize((W, W), Image.LANCZOS)


# ---------------------------------------------------------------------------
# figures and props
# ---------------------------------------------------------------------------

def side_body(c, lean=0.0, hip=(104, 196), facing=1):
    """Seated/standing figure seen from the side, facing right. Returns the shoulder point."""
    v = (math.sin(math.radians(lean)), -math.cos(math.radians(lean)))
    sh = add(hip, mul(v, 100))
    c.line(hip, sh, 40, BODY)
    head = add(sh, add(mul(v, 30), (0, 0)))
    c.circ(head, 17, BODY)
    c.poly([add(head, (14, -2)), add(head, (23, 4)), add(head, (13, 8))], BODY)  # nose
    c.line(add(hip, (-12, 8)), add(hip, (34, 8)), 14, BODY_DARK)
    return sh


def front_body(c, dy=0.0, back=False):
    c.rrect(98, 88 + dy, 158, 196, 20, BODY)
    c.rrect(116, 78 + dy, 140, 94 + dy, 6, BODY_DARK)  # neck
    c.circ((128, 58 + dy), 18, BODY)
    if back:
        c.circ((128, 58 + dy), 18, BODY_DARK)
    return (100, 96 + dy), (156, 96 + dy)  # working (image-left) and other shoulder


def arm(c, sh, up, fore, hand=None, lens=(58, 50), col=ARM, w=11, hand_len=17, thumb=False, hand_col=None):
    e = add(sh, mul(dirv(up), lens[0]))
    wr = add(e, mul(dirv(fore), lens[1]))
    c.line(sh, e, w, col)
    c.line(e, wr, w - 1, col)
    ha = fore if hand is None else hand
    tip = add(wr, mul(dirv(ha), hand_len))
    c.line(wr, tip, 9, hand_col or HAND)
    if thumb:
        c.line(add(wr, mul(dirv(ha), 4)), add(add(wr, mul(dirv(ha), 11)), (0, -9)), 4, hand_col or HAND)
    return e, wr, tip


def table(c, y, x0=120, x1=252):
    c.rrect(x0, y, x1, y + 8, 3, PROP)
    c.line((x1 - 14, y + 8), (x1 - 14, 250), 5, PROP, caps=False)


def wall(c, x):
    c.rrect(x, 18, x + 12, 252, 2, PROP)


def band(c, a, b, taut=1.0):
    c.line(a, b, 3.2, AMBER)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    c.circ(a, 3.5, AMBER)
    c.circ(b, 3.5, AMBER)


def dumbbell(c, centre, ang=90, size=1.0):
    d = dirv(ang)
    a, b = add(centre, mul(d, -7 * size)), add(centre, mul(d, 7 * size))
    c.line(a, b, 3, INK, caps=False)
    for p in (a, b):
        c.ell(p, 4.5 * size, 7 * size, ang + 90, INK)


def anchor(c, p):
    c.circ(p, 5, PROP)


# ---------------------------------------------------------------------------
# exercise scenes: each draws one frame; p in 0..1 (smooth loop), t = raw loop time
# ---------------------------------------------------------------------------

def elbow_flexion(c, p, t):
    sh = side_body(c)
    c.line(sh, add(sh, (0, 0)), 1, BODY)
    e, wr, tip = arm(c, sh, 0, 150 * p, thumb=True)
    c.glow((sh[0] + 9, sh[1] + 28), 8, 18, 0, 0.6 + 0.4 * p)
    arm(c, sh, 0, 150 * p, thumb=True)
    c.arc(e, 24, 10, 10 + 130 * max(p, 0.15), INK)


def shoulder_ext_rot(c, p, t):
    sh, osh = front_body(c)
    arm(c, osh, 0, 6, lens=(56, 48), col=ARM_FAR)
    c.glow((sh[0] - 4, sh[1] + 2), 14, 11, 90, 0.8)
    e, wr, tip = rotating_forearm(c, sh, 80 - 120 * p)
    anchor(c, (214, e[1] + 4))
    band(c, tip, (214, e[1] + 4))
    c.arc(e, 22, 80, 80 - 115, INK)


def rotating_forearm(c, sh, phi, upper=56, fore=48):
    """Upper arm at the side, elbow bent 90 degrees, forearm turning in the horizontal plane.
    phi is the turn from straight ahead (0) toward the body (+) or away from it (-), in degrees."""
    e = add(sh, (0, upper))
    r = math.radians(phi)
    wr = (e[0] + fore * math.sin(r), e[1] + 2)
    tip = (wr[0] + 14 * math.sin(r), wr[1] + 1)
    c.line(sh, e, 11, ARM)
    c.line(e, wr, 10, ARM)
    c.line(wr, tip, 9, HAND)
    return e, wr, tip


def forearm_roll(c, p, t, dumb=False):
    sh = side_body(c)
    e, wr, tip = arm(c, sh, 15, 90, lens=(58, 50), hand=90, hand_len=2)
    roll = math.radians(180 * p)
    h = 5 + 11 * abs(math.cos(roll))
    palm_up = math.cos(roll) < 0
    cx = (wr[0] + 14, wr[1])
    c.rrect(cx[0] - 17, cx[1] - h / 2, cx[0] + 17, cx[1] + h / 2, 5, "#CFE6E4" if palm_up else HAND)
    c.line((cx[0] - 12, cx[1] - h / 2 + 2), (cx[0] + 4, cx[1] - h / 2 + 2), 2.4, INK, 200, caps=False)  # thumb edge
    c.glow(((e[0] + wr[0]) / 2, wr[1]), 22, 8, 90, 0.9)
    c.arc((wr[0] + 14, wr[1]), 26, 150, 150 + 190 * max(p, 0.2), INK, 2.2)


def shoulder_abduction(c, p, t, full_can=False):
    sh, osh = front_body(c)
    ang = 90 * p if not full_can else 82 * p
    arm(c, osh, 2 + ang * 0.0, 2, lens=(56, 50), col=ARM_FAR)
    if full_can:
        arm(c, osh, ang, ang, lens=(40, 34), col=ARM_FAR, thumb=True, hand_len=10)
    c.glow((sh[0] - 8 - 6 * p, sh[1] - 2), 13, 12, 0, 0.5 + 0.5 * p)
    e, wr, tip = arm(c, sh, -ang, -ang, lens=(58, 50) if not full_can else (40, 34), thumb=full_can, hand_len=17 if not full_can else 10)
    c.arc(sh, 70, -8, -8 - 76 * max(p, 0.2), INK, 2.2)


def wrist_on_table(c, p, t, kind):
    sh = side_body(c)
    table(c, 154)
    e, wr, tip = arm(c, sh, 22, 90, hand=90, hand_len=0)
    ang = {"flex": 90 + 62 * p, "ext": 90 + 55 * p, "rev": 90 + 55 * p}[kind]
    tip = add(wr, mul(dirv(ang), 20))
    c.line(wr, tip, 10, HAND)
    palm_down = kind in ("ext", "rev")
    side = (0, 5) if palm_down else (0, -5)
    c.line(add(wr, side), add(tip, side), 2.6, "#CFE6E4", 220, caps=False)  # palm side
    if kind != "ext":
        dumbbell(c, add(tip, mul(dirv(ang), 6)), ang + 90, 0.9)
    gy = 150 if palm_down else 153
    c.glow(((e[0] + wr[0]) / 2 + 4, gy - (4 if palm_down else -4)), 24, 6, 90, 0.5 + 0.5 * p)
    c.arc(wr, 34, 92, 92 + 56 * max(p, 0.2), INK, 2.2)


def scapular(c, p, t, hold=False):
    sh, osh = front_body(c, back=True)
    sep = 26 - 18 * p
    for sgn in (-1, 1):
        cx = 128 + sgn * sep
        c.glow((cx, 126), 11, 16, sgn * 12, 0.6 + 0.4 * p)
        c.poly([(cx, 108), (cx + sgn * 17, 118), (cx + sgn * 3, 150)], ARM, 255)
    ang = 38 + 14 * p
    arm(c, sh, -ang, -ang - 82, lens=(44, 40), col=ARM_FAR, hand_len=10)
    arm(c, osh, ang, ang + 82, lens=(44, 40), col=ARM_FAR, hand_len=10)
    c.arrow((92, 126), (110, 126), INK)
    c.arrow((164, 126), (146, 126), INK)
    if hold:
        c.arc((128, 40), 0.001, 0, 0, INK, 0.1, 0)
        n = int(360 * t)
        pts = [add((214, 40), mul(dirv(180 + a), 14)) for a in range(0, n + 1, 6)]
        c.ring((214, 40), 14, INK, 2, 70)
        for i in range(len(pts) - 1):
            c.line(pts[i], pts[i + 1], 3.2, AMBER, caps=False)


def pendulum(c, p, t):
    hip = (92, 200)
    sh = side_body(c, lean=64, hip=hip)
    table(c, 168, 60, 130)
    swing = 30 * math.sin(2 * math.pi * t)
    arm(c, sh, swing, swing, lens=(60, 52), hand_len=14)
    far = add(sh, (0, 0))
    c.glow(add(sh, (2, 12)), 12, 10, 0, 0.6)
    pts = [add(sh, mul(dirv(a), 116)) for a in range(-30, 31, 5)]
    for i in range(len(pts) - 1):
        c.line(pts[i], pts[i + 1], 2, INK, 90, caps=False)


def isometric_hold(c, p, t):
    sh = side_body(c)
    pulse = 0.5 + 0.5 * math.sin(2 * math.pi * 3 * t)
    arm(c, sh, 0, 90, thumb=True)
    c.glow((sh[0] + 9, sh[1] + 28), 8 + 2 * pulse, 18 + 3 * pulse, 0, 0.6 + 0.4 * pulse)
    arm(c, sh, 0, 90, thumb=True)
    c.ring((sh[0] + 9, sh[1] + 28), 22 + 8 * pulse, AMBER, 2, int(200 - 120 * pulse))
    n = int(360 * t)
    c.ring((226, 36), 14, INK, 2, 70)
    pts = [add((226, 36), mul(dirv(180 + a), 14)) for a in range(0, n + 1, 6)]
    for i in range(len(pts) - 1):
        c.line(pts[i], pts[i + 1], 3.2, AMBER, caps=False)


def shoulder_flexion(c, p, t):
    sh = side_body(c)
    ang = 90 * p
    c.glow((sh[0] + 7, sh[1] + 2), 11, 12, 0, 0.5 + 0.5 * p)
    e, wr, tip = arm(c, sh, ang, ang, thumb=True)
    c.arc(sh, 78, 0, 90 * max(p, 0.2), INK, 2.2)


def shoulder_int_rot(c, p, t):
    sh, osh = front_body(c)
    arm(c, osh, 0, 6, lens=(56, 48), col=ARM_FAR)
    c.glow((sh[0] + 8, sh[1] + 14), 12, 12, 0, 0.8)
    e, wr, tip = rotating_forearm(c, sh, -40 + 120 * p)
    anchor(c, (22, e[1] + 4))
    band(c, tip, (22, e[1] + 4))
    c.arc(e, 22, -35, -35 + 115 * max(p, 0.2), INK)


def wall_slide(c, p, t):
    sh = side_body(c, hip=(96, 196))
    wall(c, 196)
    target = (194, lerp(158, 70, p))
    up, fore = ik(sh, target, 58, 50, flip=-1)
    c.glow((sh[0] + 8, sh[1] + 4), 11, 12, 0, 0.5 + 0.5 * p)
    arm(c, sh, up, fore, lens=(58, 50), hand_len=10)
    c.arrow((184, 150), (184, 84), INK)


def table_slide(c, p, t):
    sh = side_body(c, lean=10 + 12 * p, hip=(96, 196))
    table(c, 150, 120, 252)
    target = (lerp(138, 188, p), 146)
    up, fore = ik(sh, target, 58, 50, flip=-1)
    c.rrect(target[0] - 22, 146, target[0] + 8, 150, 2, AMBER, 200)
    arm(c, sh, up, fore, lens=(58, 50), hand=90, hand_len=14)
    c.arrow((150, 140), (206, 140), INK)


def shrug(c, p, t):
    sh, osh = front_body(c, dy=-12 * p * 0)
    up = -10 * p
    for s, x in ((sh, -1), (osh, 1)):
        s2 = (s[0], s[1] - 12 * p)
        e, wr, tip = arm(c, s2, 0, 0, lens=(58, 50))
        dumbbell(c, add(tip, (0, 4)), 0, 0.9)
        c.glow((s2[0] + 8 * (-x) * -1 * -1 + x * 10, s2[1] - 12), 12, 7, x * 70, 0.5 + 0.5 * p)
    c.arrow((128, 120), (128, 88 - 10 * p), INK) if False else None
    c.arrow((70, 100), (70, 80), INK)
    c.arrow((186, 100), (186, 80), INK)


def horiz_abduction(c, p, t, y_raise=False):
    # person lying face down, seen from the head end; arms hang down then lift
    c.rrect(84, 150, 172, 164, 3, PROP)  # bench
    c.rrect(100, 126, 156, 152, 10, BODY)  # back
    c.circ((128, 168), 17, BODY_DARK)  # head (nearest the viewer)
    sh_l, sh_r = (102, 138), (154, 138)
    ang = (145 if y_raise else 90) * p
    c.glow((sh_l[0] - 6, sh_l[1] + 2), 11, 11, 0, 0.5 + 0.5 * p)
    arm(c, sh_r, 4, 4, lens=(44, 38), col=ARM_FAR, hand_len=12)
    arm(c, sh_l, -ang, -ang, lens=(44, 38), thumb=y_raise, hand_len=12)
    if y_raise:
        arm(c, sh_r, ang, ang, lens=(44, 38), col=ARM_FAR, thumb=True, hand_len=12)
    c.arc(sh_l, 62, -4, -4 - (140 if y_raise else 86) * max(p, 0.2), INK, 2.2)


def cross_body(c, p, t):
    sh, osh = front_body(c)
    ang = 40 + 48 * p
    e, wr, tip = arm(c, sh, ang, ang + 6, lens=(56, 46), hand_len=10)
    c.glow((sh[0] + 4, sh[1] + 4), 12, 10, 90, 0.5 + 0.5 * p)
    target = (e[0] + 4, e[1] + 8)
    up, fore = ik(osh, target, 50, 44, flip=1)
    arm(c, osh, up, fore, lens=(50, 44), col=ARM_FAR, hand_len=8)
    c.arrow((150, 112), (126, 112), INK)


def wall_pushup(c, p, t):
    lean = 8 + 14 * (1 - p)
    hip = (74, 204)
    sh = side_body(c, lean=lean, hip=hip)
    wall(c, 198)
    up, fore = ik(sh, (196, 104), 58, 50, flip=-1)
    arm(c, sh, up, fore, lens=(58, 50), hand_len=8)
    c.glow((sh[0] - 10, sh[1] + 18), 9, 15, 20, 0.4 + 0.6 * p)
    c.arrow((172, 150), (186, 150), INK) if p > 0.5 else c.arrow((186, 150), (172, 150), INK)


def overhead_band_press(c, p, t):
    sh, osh = front_body(c)
    ys = lerp(106, 20, p)
    for s, sgn in ((sh, -1), (osh, 1)):
        target = (s[0] + sgn * lerp(24, 10, p), ys)
        up, fore = ik(s, target, 52, 46, flip=-sgn)
        e, wr, tip = arm(c, s, up, fore, lens=(52, 46), col=ARM if sgn < 0 else ARM_FAR, hand_len=6)
        band(c, tip, (128, 244))
    c.glow((sh[0] - 6, sh[1] - 6), 12, 10, 0, 0.5 + 0.5 * p)
    c.arrow((128, 200), (128, 168 - 0), INK) if False else None


def band_pull_apart(c, p, t):
    sh, osh = front_body(c)
    xs = lerp(14, 54, p)
    pts = []
    for s, sgn in ((sh, -1), (osh, 1)):
        target = (128 + sgn * lerp(10, 82, p), 104)
        up, fore = ik(s, target, 46, 42, flip=-1 if sgn < 0 else 1)
        e, wr, tip = arm(c, s, up, fore, lens=(46, 42), col=ARM if sgn < 0 else ARM_FAR, hand_len=6)
        pts.append(tip)
    band(c, pts[0], pts[1])
    c.glow((128, 124), 18, 10, 90, 0.4 + 0.6 * p)
    c.arrow((98, 100), (80, 100), INK) if False else None


def elbow_ext_band(c, p, t):
    sh = side_body(c)
    anchor(c, (206, 22))
    e, wr, tip = arm(c, sh, 0, 150 * (1 - p), thumb=True)
    band(c, tip, (206, 22))
    c.glow((sh[0] - 6, sh[1] + 26), 8, 18, 0, 0.5 + 0.5 * p)
    c.arc(e, 24, 10 + 130 * (1 - max(p, 0.15)), 10, INK)


def hammer_curl(c, p, t):
    sh = side_body(c)
    ang = 140 * p
    e, wr, tip = arm(c, sh, 0, ang, thumb=True)
    dumbbell(c, add(tip, mul(dirv(ang), 3)), ang, 1.0)
    c.glow(add(e, mul(dirv(ang), 12)), 7, 13, ang, 0.5 + 0.5 * p)
    c.arc(e, 24, 10, 10 + 120 * max(p, 0.15), INK)


def assisted_flexion(c, p, t):
    sh = side_body(c)
    ang = 150 * p
    e, wr, tip = arm(c, sh, 0, ang, thumb=True)
    target = add(wr, (4, 14))
    up, fore = ik(add(sh, (-4, 4)), target, 52, 46, flip=-1)
    arm(c, add(sh, (-4, 4)), up, fore, lens=(52, 46), col=ARM_FAR, hand_len=8, w=9)
    c.glow(add(e, mul(dirv(ang / 2 + 40), 8)), 7, 13, 0, 0.5 + 0.5 * p)
    c.arc(e, 24, 10, 10 + 130 * max(p, 0.15), INK)


def towel_elbow(c, p, t):
    sh = side_body(c)
    ang = 120 * (1 - p)
    e, wr, tip = arm(c, sh, 0, ang, thumb=True)
    far = add(sh, (-4, 4))
    target = add(wr, (-18, 44))
    up, fore = ik(far, target, 52, 46, flip=-1)
    e2, w2, t2 = arm(c, far, up, fore, lens=(52, 46), col=ARM_FAR, hand_len=6, w=9)
    c.line(tip, t2, 5, AMBER)
    c.glow(e, 11, 11, 0, 0.5 + 0.5 * p)
    c.arc(e, 24, 10 + 100 * (1 - max(p, 0.15)), 10, INK)


def eccentric(c, p, t):
    # quick lift with both hands, slow lowering with the working arm alone
    q = t / 0.2 if t < 0.2 else 1 - (t - 0.2) / 0.8
    q = q * q * (3 - 2 * q)
    sh = side_body(c)
    ang = 150 * q
    e, wr, tip = arm(c, sh, 0, ang, thumb=True)
    dumbbell(c, add(tip, mul(dirv(ang), 3)), ang, 1.0)
    if t < 0.2:
        far = add(sh, (-4, 4))
        up, fore = ik(far, add(wr, (4, 14)), 52, 46, flip=-1)
        arm(c, far, up, fore, lens=(52, 46), col=ARM_FAR, hand_len=6, w=9)
    c.glow(add(e, mul(dirv(ang / 2 + 40), 8)), 7, 13, 0, 0.5 + 0.5 * q)
    if t >= 0.2:
        c.arrow((e[0] + 28, e[1] - 18), (e[0] + 28, e[1] + 10), INK)


def deviation(c, p, t):
    # top-down: forearm resting on a table, hand swings side to side
    c.rrect(30, 70, 240, 190, 14, "#D2E8E6")
    c.line((52, 130), (140, 130), 24, ARM)
    ang = 90 + 28 * math.sin(2 * math.pi * t)
    wr = (140, 130)
    tip = add(wr, mul(dirv(ang), 46))
    c.line(wr, tip, 20, HAND)
    for k in (-1, 0, 1):
        c.line(add(tip, mul(dirv(ang + 90), k * 6)), add(add(tip, mul(dirv(ang + 90), k * 6)), mul(dirv(ang), 12)), 4, HAND)
    c.glow(add(wr, mul(dirv(ang + 90), 10)), 9, 14, ang, 0.6)
    c.arc(wr, 56, 62, 118, INK, 2.2)
    c.arc(wr, 56, 118, 62, INK, 2.2)


def wrist_circles(c, p, t):
    c.rrect(30, 70, 240, 190, 14, "#D2E8E6")
    c.line((52, 130), (140, 130), 24, ARM)
    th = 2 * math.pi * t
    ang = 90 + 24 * math.cos(th)
    ln = 44 * (0.85 + 0.15 * math.sin(th))
    wr = (140, 130)
    tip = add(wr, mul(dirv(ang), ln))
    c.line(wr, tip, 20, HAND)
    for k in (-1, 0, 1):
        c.line(add(tip, mul(dirv(ang + 90), k * 6)), add(add(tip, mul(dirv(ang + 90), k * 6)), mul(dirv(ang), 12)), 4, HAND)
    c.ring((196, 130), 24, INK, 2, 90)
    c.circ(add((196, 130), (24 * math.cos(th), 24 * math.sin(th))), 4.5, AMBER)
    c.glow(wr, 14, 10, 0, 0.5)


def wrist_stretch(c, p, t):
    sh = side_body(c)
    e, wr, tip = arm(c, sh, 90, 90, hand=90, hand_len=0)
    ang = 90 - 62 * p
    hand_tip = add(wr, mul(dirv(ang), 20))
    c.line(wr, hand_tip, 10, HAND)
    c.glow(((e[0] + wr[0]) / 2, e[1] + 4), 24, 6, 90, 0.4 + 0.6 * p)
    far = add(sh, (-2, 6))
    target = add(hand_tip, (4, 8))
    up, fore = ik(far, target, 56, 50, flip=-1)
    arm(c, far, up, fore, lens=(56, 50), col=ARM_FAR, hand_len=6, w=9)
    c.arc(wr, 34, 90, 90 - 56 * max(p, 0.2), INK, 2.2)


def finger(c, base, bends, ls=1.0, w=12):
    """One finger seen from the palm side: it points up and, as it bends, folds toward the viewer
    (so it shortens on screen) rather than swinging sideways. bends = degrees at each joint."""
    segs = (30, 22, 17)
    pos, cum = base, 0.0
    for i, (L, b) in enumerate(zip(segs, bends)):
        cum += b
        nxt = (pos[0], pos[1] - L * ls * math.cos(math.radians(cum)))
        c.line(pos, nxt, w - i * 1.5, ARM)
        c.circ(pos, (w - i * 1.5) / 2 + 0.8, "#0F8A93")
        pos = nxt
    c.circ(pos, (w - 3) / 2 + 0.5, ARM)
    return pos


FINGERS = [(-27, 0.9), (-9, 1.0), (9, 0.96), (27, 0.82)]


def palm(c, centre=(128, 150)):
    px, py = centre
    c.rrect(px - 38, py - 4, px + 38, py + 62, 22, BODY)
    return px, py


def hand_base(c, curl, centre=(128, 150)):
    px, py = palm(c, centre)
    return [finger(c, (px + bx, py - 2), (curl * 70, curl * 95, curl * 70), ls) for bx, ls in FINGERS]


def putty(c, p, t):
    curl = 0.2 + 0.7 * p
    hand_base(c, curl)
    r = lerp(32, 21, p)
    c.ell((128, 146), r * 1.15, r * 0.9, 90, AMBER, 235)
    c.glow((128, 160), 30, 16, 90, 0.4 + 0.6 * p)


def tendon_glides(c, p, t):
    # straight -> hook -> fist -> straight
    poses = [(0, 0, 0), (0, 80, 55), (85, 100, 70), (0, 80, 55)]
    seg = (t * 4) % 4
    i = int(seg)
    f = seg - i
    f = f * f * (3 - 2 * f)
    a, b = poses[i], poses[(i + 1) % 4]
    bends = tuple(lerp(x, y, f) for x, y in zip(a, b))
    px, py = palm(c)
    for bx, ls in FINGERS:
        finger(c, (px + bx, py - 2), bends, ls)
    c.glow((128, 150), 34, 14, 90, 0.4 + 0.1 * (sum(bends) / 100))
    for k in range(4):
        c.circ((92 + k * 24, 236), 6 if k == i else 4, AMBER if k == i else PROP)


def pinch(c, p, t):
    px, py = palm(c)
    which = int(t * 4) % 4
    squeeze = 0.5 + 0.5 * math.sin(2 * math.pi * 4 * t)
    tips = []
    for k, (bx, ls) in enumerate(FINGERS):
        bends = (35, 45, 30) if k == which else (12, 18, 10)
        tips.append(finger(c, (px + bx, py - 2), bends, ls))
    target = tips[which]
    base = (px - 40, py + 44)
    up, fore = ik(base, add(target, (-6, 10)), 38, 34, flip=1)
    e = add(base, mul(dirv(up), 38))
    c.line(base, e, 13, ARM)
    c.line(e, add(e, mul(dirv(fore), 34)), 11, ARM)
    c.circ(add(target, (-3, 6)), 8 - 2 * squeeze, AMBER)
    c.glow(add(target, (-2, 5)), 16, 16, 0, 0.5 + 0.5 * squeeze)
    for k in range(4):
        c.circ((92 + k * 24, 236), 6 if k == which else 4, AMBER if k == which else PROP)


def towel_wring(c, p, t):
    th = 2 * math.pi * osc(t) * 0.5 * 2
    twist = osc(t)
    # towel: two stripes twisting between the hands
    xs = [i for i in range(60, 197, 4)]
    for off, col in ((-1, AMBER), (1, "#F3CC96")):
        pts = []
        for x in xs:
            phase = (x - 60) / 136.0
            y = 130 + 16 * off * math.sin(phase * 6 * twist * math.pi + 0.6 * twist)
            pts.append((x, y))
        for i in range(len(pts) - 1):
            c.line(pts[i], pts[i + 1], 11, col, caps=False)
    for sgn, x in ((-1, 62), (1, 194)):
        c.rrect(x - 17, 130 - 25, x + 17, 130 + 25, 12, ARM)
        c.line((x - 8, 130 - 14), (x + 8, 130 - 14), 3, "#CFE6E4", 200, caps=False)
    c.arc((62, 130), 40, 160, 160 - 120 * max(twist, 0.15), INK, 2.2)
    c.arc((194, 130), 40, 20, 20 + 120 * max(twist, 0.15), INK, 2.2)
    c.glow((128, 130), 30, 10, 90, 0.4 + 0.6 * twist)


SCENES = {
    "Elbow Flexion & Extension": elbow_flexion,
    "Shoulder External Rotation": shoulder_ext_rot,
    "Forearm Supination/Pronation": forearm_roll,
    "Shoulder Abduction Raise": shoulder_abduction,
    "Wrist Flexion Curl": lambda c, p, t: wrist_on_table(c, p, t, "flex"),
    "Scapular Retraction": scapular,
    "Pendulum Arm Swing": pendulum,
    "Isometric Bicep Hold": isometric_hold,
    "Shoulder Flexion Raise": shoulder_flexion,
    "Shoulder Internal Rotation": shoulder_int_rot,
    "Wall Slide": wall_slide,
    "Table Slide": table_slide,
    "Shoulder Shrug": shrug,
    "Full Can Raise": lambda c, p, t: shoulder_abduction(c, p, t, full_can=True),
    "Shoulder Horizontal Abduction": horiz_abduction,
    "Cross-Body Shoulder Stretch": cross_body,
    "Wall Push-Up Plus": wall_pushup,
    "Overhead Resistance Band Press": overhead_band_press,
    "Scapular Squeeze Hold": lambda c, p, t: scapular(c, 1.0, t, hold=True),
    "Prone Y Raise": lambda c, p, t: horiz_abduction(c, p, t, y_raise=True),
    "Band Pull-Apart": band_pull_apart,
    "Elbow Extension with Band": elbow_ext_band,
    "Hammer Curl": hammer_curl,
    "Active Assisted Elbow Flexion": assisted_flexion,
    "Towel Elbow Stretch": towel_elbow,
    "Eccentric Bicep Lowering": eccentric,
    "Wrist Extension Curl": lambda c, p, t: wrist_on_table(c, p, t, "ext"),
    "Radial & Ulnar Deviation": deviation,
    "Wrist Circles": wrist_circles,
    "Reverse Wrist Curl": lambda c, p, t: wrist_on_table(c, p, t, "rev"),
    "Wrist Flexor Stretch": wrist_stretch,
    "Putty Squeeze": putty,
    "Finger Tendon Glides": tendon_glides,
    "Pinch Strengthening": pinch,
    "Towel Wring": towel_wring,
}


def slugify(name):
    s = name.lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def render(fn):
    frames = []
    for i in range(FRAMES):
        t = i / FRAMES
        c = Canvas()
        fn(c, osc(t), t)
        frames.append(c.finish())
    return frames


def save_webp(frames, path):
    frames[0].save(
        path,
        format="WEBP",
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_MS,
        loop=0,
        quality=72,
        method=6,
    )


def main(only=None):
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        names = [r["name"] for r in csv.DictReader(f)]
    missing = [n for n in names if n not in SCENES]
    if missing:
        sys.exit("No illustration defined for: " + ", ".join(missing))
    os.makedirs(OUT_WEB, exist_ok=True)
    os.makedirs(OUT_APP, exist_ok=True)
    rows = []
    for name in names:
        slug = slugify(name)
        if only and slug not in only:
            rows.append((name, slug))
            continue
        frames = render(SCENES[name])
        out = os.path.join(OUT_WEB, slug + ".webp")
        save_webp(frames, out)
        shutil.copyfile(out, os.path.join(OUT_APP, slug + ".webp"))
        print(f"{slug}.webp  {os.path.getsize(out) // 1024} KB")
        rows.append((name, slug))

    values = ",\n".join(
        "  ('{}', 'exercises/{}.webp')".format(n.replace("'", "''"), s) for n, s in rows
    )
    sql = f"""-- Attaches a short looping illustration to each exercise.
--
-- media_url is a path relative to the apps ('exercises/<slug>.webp'): the web
-- portal serves it from /exercises/, the mobile app bundles it under
-- assets/exercises/. A full https:// URL also works (a real recorded video,
-- say), so any exercise's media can be swapped without a code change.
-- media_type is 'image' (the animated illustrations) or 'video'.
--
-- Generated by scripts/generate_exercise_illustrations.py - re-run that rather
-- than editing this by hand. Idempotent. Run after supabase_seed_exercises.sql.

alter table public.exercises add column if not exists media_url  text;
alter table public.exercises add column if not exists media_type text not null default 'image'
  check (media_type in ('image', 'video'));

update public.exercises e
set media_url = v.media_url
from (values
{values}
) as v(name, media_url)
where e.name = v.name
  and e.media_url is distinct from v.media_url
  and (e.media_url is null or e.media_url like 'exercises/%');
"""
    with open(SQL_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    print("wrote", os.path.relpath(SQL_PATH, ROOT))


if __name__ == "__main__":
    main(set(sys.argv[1:]) or None)

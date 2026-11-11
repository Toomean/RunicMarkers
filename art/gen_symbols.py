"""Hand-scratched marker symbol set (own drawings). Each stroke is a polyline drawn as ONE continuous
carved stroke (tapered ends, wobble, uneven width). Plus helper marks (MARKS, e.g. the delete aim dot), written
in the "outlined" style only. Stdlib only. Usage: gen_symbols.py OUTDIR [seed]
PNGs: rsvg-convert outlined_<name>.svg -o outlined_<name>.png (512 px, reproduces the committed PNGs)."""
import math, random, sys, os

def arc(cx, cy, r, a0, a1, n=40, ry=None):
    ry = r if ry is None else ry
    return [(cx + r*math.cos(math.radians(a0+(a1-a0)*i/n)), cy + ry*math.sin(math.radians(a0+(a1-a0)*i/n))) for i in range(n+1)]

def wave(y, x0=.12, x1=.88, amp=.06, periods=1.5, n=40):
    return [(x0+(x1-x0)*i/n, y + amp*math.sin(2*math.pi*periods*i/n)) for i in range(n+1)]

SYMBOLS = {  # unit square, y down
 "x_visited": [[(.2,.2),(.8,.8)], [(.8,.2),(.2,.8)]],
 "o_other":   [arc(.5,.5,.31,-80,265,48)],                     # deliberately not quite closed
 "innos":     [arc(.5,.5,.14,0,350,30)] +                       # sun: disc + 8 rays
              [[(.5+.22*math.cos(math.radians(a)), .5+.22*math.sin(math.radians(a))),
                (.5+.38*math.cos(math.radians(a)), .5+.38*math.sin(math.radians(a)))] for a in range(0,360,45)],
 "beliar":    [arc(.5,.5,.32,50,310,44), arc(.62,.46,.25,75,285,36)],              # crescent moon: outer + inner arc
 "adanos":    [wave(.32), wave(.5), wave(.68)],                 # water: three waves
 "sleeper":   [arc(.5,.42,.32,20,160,30,.2)] +                  # closed eye: lid arc + hanging lashes
              [[(.5+.32*math.cos(math.radians(a)), .42+.2*math.sin(math.radians(a))),
                (.5+.40*math.cos(math.radians(a)), .42+.31*math.sin(math.radians(a)))] for a in (40,65,90,115,140)],
 "human":     [arc(.5,.2,.09,0,350,24), [(.5,.3),(.5,.6)], [(.28,.42),(.72,.42)],
               [(.5,.6),(.33,.86)], [(.5,.6),(.67,.86)]],
}

# Helper marks, NOT placeable symbols (no mask/glow, not on the sheet, not in the game's symbol list):
# "dot" = small filled disc for the delete aim (cx, cy, r in the unit square).
MARKS = {
 "dot": (.5, .5, .3),
}

S, MARGIN = 512, 50
OUTLINE_PX = 10  # total stroke width; ~5 px dark edge outside the white stroke
def px(p): return (MARGIN + p[0]*(S-2*MARGIN), MARGIN + p[1]*(S-2*MARGIN))

def resample(pts, step):
    out, acc = [pts[0]], 0.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        L = math.hypot(bx-ax, by-ay); t = step - acc
        while t <= L:
            out.append((ax+(bx-ax)*t/L, ay+(by-ay)*t/L)); t += step
        acc = (acc + L) % step
    if out[-1] != pts[-1]: out.append(pts[-1])
    return out

def carved(poly, rng, base_w):
    pts = [px(p) for p in poly]
    # over/undershoot at both ends, along end tangents
    for idx, nb in ((0, 1), (-1, -2)):
        (x, y), (qx, qy) = pts[idx], pts[nb]
        L = math.hypot(x-qx, y-qy) or 1; k = rng.uniform(-6, 14)
        pts[idx] = (x + (x-qx)/L*k, y + (y-qy)/L*k)
    pts = resample(pts, 5.0)
    n = len(pts) - 1
    ph = [rng.uniform(0, 6.28) for _ in range(3)]
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(i-1, 0)], pts[min(i+1, n)]
        tx, ty = b[0]-a[0], b[1]-a[1]; L = math.hypot(tx, ty) or 1
        nx, ny = -ty/L, tx/L
        t = i/n if n else 0
        off = math.sin(t*3.1*max(1, n/40)+ph[0])*2.0 + math.sin(t*11.0*max(1, n/40)+ph[1])*0.9 + rng.uniform(-.5, .5)
        taper = math.sin(math.pi*min(1, max(0, t*0.9+0.05)))**0.45
        w = base_w*taper*(0.82 + 0.22*math.sin(t*7.0+ph[2]) + rng.uniform(-.05, .05))
        cx, cy = x+nx*off, y+ny*off
        left.append((cx+nx*w/2, cy+ny*w/2)); right.append((cx-nx*w/2, cy-ny*w/2))
    return "M" + " L".join(f"{a:.1f} {b:.1f}" for a, b in left + right[::-1]) + " Z"

def blob(cx, cy, r, rng, n=48):
    """Filled disc with an uneven, hand-cut rim (same wobble idea as carved())."""
    ph = [rng.uniform(0, 6.28) for _ in range(2)]
    pts = []
    for i in range(n):
        a = 2*math.pi*i/n
        k = 1 + .06*math.sin(3*a+ph[0]) + .03*math.sin(7*a+ph[1]) + rng.uniform(-.015, .015)
        pts.append(px((cx + r*k*math.cos(a), cy + r*k*math.sin(a))))
    return "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"

def paths(name, seed):
    rng = random.Random(f"{name}-{seed}"); out = []
    if name in MARKS:
        return [(blob(*MARKS[name], rng), 1.0)]
    for poly in SYMBOLS[name]:
        out.append((carved(poly, rng, 24), 1.0))
        if rng.random() < 0.5:  # second, thinner pass of the blade
            j = [(x+rng.uniform(-.01,.01), y+rng.uniform(-.01,.01)) for x, y in poly]
            out.append((carved(j, rng, 10), 0.7))
    return out

def svg(name, seed, mode):
    body = "".join(f'<path d="{d}" opacity="{o}"/>' for d, o in paths(name, seed))
    head = f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">'
    if mode == "mask":
        return head + f'<g fill="#fff">{body}</g></svg>'
    if mode == "outlined":  # dark carved edge under the same white stroke: reads on light stone too
        return (head + f'<g fill="#2a2018" stroke="#2a2018" stroke-width="{OUTLINE_PX}" stroke-linejoin="round" opacity="0.85">{body}</g>'
                f'<g fill="#fff">{body}</g></svg>')
    return (head + '<defs><filter id="g" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="13"/></filter></defs>'
            f'<g fill="#5fd0ff" stroke="#5fd0ff" stroke-width="16" filter="url(#g)" opacity="0.95">{body}</g>'
            f'<g fill="#e8fbff">{body}</g></svg>')

if __name__ == "__main__":
    outdir = sys.argv[1]; seed = sys.argv[2] if len(sys.argv) > 2 else "1"
    os.makedirs(outdir, exist_ok=True)
    for name in SYMBOLS:
        for mode in ("mask", "glow", "outlined"):
            open(os.path.join(outdir, f"{mode}_{name}.svg"), "w").write(svg(name, seed, mode))
    for name in MARKS:  # only the decal source style
        open(os.path.join(outdir, f"outlined_{name}.svg"), "w").write(svg(name, seed, "outlined"))
    cell, names = 230, list(SYMBOLS)
    sheet = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{len(names)*cell}" height="{cell+40}">',
             '<rect width="100%" height="100%" fill="#1d1c1a"/>']
    for i, name in enumerate(names):
        sheet.append(f'<image x="{i*cell+10}" y="10" width="{cell-20}" height="{cell-20}" xlink:href="glow_{name}.png"/>')
        sheet.append(f'<text x="{i*cell+cell/2}" y="{cell+22}" fill="#bbb" font-family="Helvetica" font-size="20" text-anchor="middle">{name}</text>')
    open(os.path.join(outdir, "sheet.svg"), "w").write("".join(sheet) + "</svg>")

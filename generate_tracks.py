"""
Generate 5 km non-looping RL training tracks.

Coordinate system (metres):
  lon  = forward direction
  lat  = lateral direction (positive = left)
  elevation = vertical

Each track is 200 segments × 25 m = 5 000 m total.
"""

import json, math, os

OUT_DIR = "master-thesis/stages"
STEP    = 25.0   # metres between waypoints
STEPS   = 200    # number of segments → 201 points, 5 000 m total


def build_track(heading_fn, elevation_fn):
    """
    Trace a path step by step.
    heading_fn(i)   → heading in radians at step i (0 = +lon, π/2 = +lat)
    elevation_fn(i) → elevation in metres at step i
    """
    lat = lon = 0.0
    pts = [{"lat": 0.0, "lon": 0.0, "elevation": round(elevation_fn(0), 4)}]
    for i in range(1, STEPS + 1):
        h = heading_fn(i)
        lat += STEP * math.sin(h)
        lon += STEP * math.cos(h)
        pts.append({
            "lat":       round(lat, 4),
            "lon":       round(lon, 4),
            "elevation": round(elevation_fn(i), 4),
        })
    return pts


def save(name, pts):
    path = os.path.join(OUT_DIR, name)
    with open(path, "w") as f:
        json.dump(pts, f, indent=2)
    total = STEPS * STEP
    print(f"  {name:45s}  {len(pts)} pts  {total:.0f} m")


def const_h(angle):
    return lambda i: angle

def lin_h(start, end):
    return lambda i: start + (end - start) * i / STEPS

def s_h(peak):
    """Heading rises to peak at midpoint then returns to 0."""
    return lambda i: peak * math.sin(math.pi * i / STEPS)

def zigzag_h(amplitude, period_steps):
    """Sawtooth heading: alternates ±amplitude every period_steps."""
    def fn(i):
        phase = (i % period_steps) / period_steps  # 0→1
        # triangle wave: 0→1→0 in first half, 0→-1→0 in second
        cycle = (i // period_steps) % 2
        tri = 4 * phase - 1 if phase < 0.5 else 3 - 4 * phase
        return amplitude * tri * (1 if cycle == 0 else -1)
    return fn

def flat_e():          return lambda i: 0.0
def linear_e(total):   return lambda i: total * i / STEPS
def sine_e(amp, n):    return lambda i: amp * math.sin(2 * math.pi * n * i / STEPS)
def valley_e(depth):
    return lambda i: -depth * math.sin(math.pi * i / STEPS)
def mountain_e(height):
    return lambda i: height * math.sin(math.pi * i / STEPS)

print("Generating 5 km RL tracks:")

# ── Straight tracks ───────────────────────────────────────────────────────────
save("rl-5k-straight-flat.json",
     build_track(const_h(0), flat_e()))

save("rl-5k-straight-uphill.json",
     build_track(const_h(0), linear_e(+250)))

save("rl-5k-straight-downhill.json",
     build_track(const_h(0), linear_e(-250)))

# ── Elevation variety (straight path) ─────────────────────────────────────────
save("rl-5k-rolling-hills.json",           # 4 complete hills, ±80 m
     build_track(const_h(0), sine_e(80, 4)))

save("rl-5k-valley.json",                  # descends 200 m then climbs back
     build_track(const_h(0), valley_e(200)))

save("rl-5k-mountain.json",                # climbs 200 m then descends back
     build_track(const_h(0), mountain_e(200)))

# ── Horizontal curves, flat ───────────────────────────────────────────────────
save("rl-5k-left-arc.json",                # smooth 90° left turn
     build_track(lin_h(0, math.pi / 2), flat_e()))

save("rl-5k-right-arc.json",               # smooth 90° right turn
     build_track(lin_h(0, -math.pi / 2), flat_e()))

save("rl-5k-s-curve.json",                 # left 45° then back to straight
     build_track(s_h(math.pi / 4), flat_e()))

save("rl-5k-zigzag.json",                  # alternates ±25° every 500 m
     build_track(zigzag_h(math.radians(25), 20), flat_e()))

# ── Combined curves + elevation ───────────────────────────────────────────────
save("rl-5k-left-arc-uphill.json",         # 90° left + climbs 200 m
     build_track(lin_h(0, math.pi / 2), linear_e(200)))

save("rl-5k-right-arc-downhill.json",      # 90° right + drops 200 m
     build_track(lin_h(0, -math.pi / 2), linear_e(-200)))

save("rl-5k-s-curve-uphill.json",          # S-curve + climbs 150 m
     build_track(s_h(math.pi / 4), linear_e(150)))

save("rl-5k-rolling-left-arc.json",        # rolling hills + 60° left arc
     build_track(lin_h(0, math.pi / 3), sine_e(60, 3)))

print("Done.")

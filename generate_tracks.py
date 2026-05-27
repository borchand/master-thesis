"""
Generate 2 km non-looping RL training tracks.

Coordinate system (metres):
  lon  = forward direction
  lat  = lateral direction (positive = left)
  elevation = vertical

Each track is 40 segments × 50 m = 2 000 m total.
"""

import json, math, os

OUT_DIR = "master-thesis/stages"
STEP    = 50.0   # metres between waypoints
STEPS   = 40     # number of segments → 41 points, 2 000 m total


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


def build_hairpin_track(step=10.0, hairpin_radius=40.0, elevation_fn=None, total_m=2000.0):
    """
    Track with two tight hairpin U-turns.
    Layout: long straight → hairpin right → long straight back →
            hairpin right (from rider's perspective) → long straight forward.
    step          : metres between waypoints (smaller = smoother turn)
    hairpin_radius: turning radius in metres (40 m ≈ tight mountain hairpin)
    total_m       : approximate total track length in metres
    """
    if elevation_fn is None:
        elevation_fn = lambda d: 0.0

    arc_len    = math.pi * hairpin_radius          # 180° arc length
    turn_steps = max(2, round(arc_len / step))     # waypoints for the U-turn
    arc_total  = 2 * turn_steps * step
    straight_m = (total_m - arc_total) / 3.0       # three straight segments
    str_steps  = round(straight_m / step)

    headings = []

    # Segment 1: straight forward (heading = 0)
    headings += [0.0] * str_steps

    # Hairpin 1: (right U-turn)
    for i in range(1, turn_steps + 1):
        headings.append(-math.pi * i / turn_steps)


    # Hairpin 2: (left U-turn)
    for i in range(1, turn_steps + 1):
        headings.append(-math.pi + math.pi * i / turn_steps)

    # Segment 2: straight forward (heading ≈ -2π ≡ 0)
    headings += [0.0] * str_steps

    # Hairpin 3: (left U-turn)
    for i in range(1, turn_steps + 1):
        headings.append(math.pi * i / turn_steps)

    # Hairpin 4: (right U-turn)
    for i in range(1, turn_steps + 1):
        headings.append(-math.pi - math.pi * i / turn_steps)


   
    # Segment 3: straight (heading = 0)
    headings += [0.0] * str_steps

    # Trace path
    lat = lon = 0.0
    dist = 0.0
    pts = [{"lat": 0.0, "lon": 0.0, "elevation": round(elevation_fn(0.0), 4)}]
    for h in headings:
        lat  += step * math.sin(h)
        lon  += step * math.cos(h)
        dist += step
        pts.append({"lat": round(lat, 4), "lon": round(lon, 4),
                    "elevation": round(elevation_fn(dist), 4)})

    actual_m = len(headings) * step
    print(f"  {'(hairpin)':45s}  {len(pts)} pts  {actual_m:.0f} m")
    return pts


def save_hairpin(name, pts):
    path = os.path.join(OUT_DIR, name)
    with open(path, "w") as f:
        json.dump(pts, f, indent=2)


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

print("Generating 2 km RL tracks:")

# ── Straight tracks ───────────────────────────────────────────────────────────
save("rl-2k-straight-flat.json",
     build_track(const_h(0), flat_e()))

save("rl-2k-straight-uphill.json",
     build_track(const_h(0), linear_e(+250)))

save("rl-2k-straight-downhill.json",
     build_track(const_h(0), linear_e(-250)))

# ── Elevation variety (straight path) ─────────────────────────────────────────
save("rl-2k-rolling-hills.json",           # 4 complete hills, ±80 m
     build_track(const_h(0), sine_e(80, 4)))

save("rl-2k-valley.json",                  # descends 200 m then climbs back
     build_track(const_h(0), valley_e(200)))

save("rl-2k-mountain.json",                # climbs 200 m then descends back
     build_track(const_h(0), mountain_e(200)))

# ── Horizontal curves, flat ───────────────────────────────────────────────────
save("rl-2k-left-arc.json",                # smooth 90° left turn
     build_track(lin_h(0, math.pi / 2), flat_e()))

save("rl-2k-right-arc.json",               # smooth 90° right turn
     build_track(lin_h(0, -math.pi / 2), flat_e()))

save("rl-2k-s-curve.json",                 # left 45° then back to straight
     build_track(s_h(math.pi / 4), flat_e()))

save("rl-2k-zigzag.json",                  # alternates ±25° every 2 km
     build_track(zigzag_h(math.radians(25), 20), flat_e()))

# ── Combined curves + elevation ───────────────────────────────────────────────
save("rl-2k-left-arc-uphill.json",         # 90° left + climbs 200 m
     build_track(lin_h(0, math.pi / 2), linear_e(200)))

save("rl-2k-right-arc-downhill.json",      # 90° right + drops 200 m
     build_track(lin_h(0, -math.pi / 2), linear_e(-200)))

save("rl-2k-s-curve-uphill.json",          # S-curve + climbs 150 m
     build_track(s_h(math.pi / 4), linear_e(150)))

save("rl-2k-rolling-left-arc.json",        # rolling hills + 60° left arc
     build_track(lin_h(0, math.pi / 3), sine_e(60, 3)))

print("Done.")

# ── Technical circuit ─────────────────────────────────────────────────────────

def build_technical_track(step=10.0, elevation_fn=None):
    """
    ~2 km mixed-feature track:
      opening straight → chicane (right 45°/left 45°) → tight right 90° →
      straight → tight left 90° → S-bend (right 60°/left 60°) →
      tight 180° hairpin left → return straight.

    Uses 10 m steps for smooth corners.
    """
    if elevation_fn is None:
        elevation_fn = lambda d: 0.0

    headings = []
    heading = 0.0

    def straight(length):
        n = max(1, round(length / step))
        headings.extend([heading] * n)

    def arc(radius, delta):
        nonlocal heading
        n = max(2, round(abs(delta) * radius / step))
        for k in range(1, n + 1):
            headings.append(heading + delta * k / n)
        heading += delta

    straight(400)
    arc(40, -math.pi / 4)   # chicane: right 45°
    straight(40)
    arc(40, +math.pi / 4)   # chicane: left 45° back to straight
    straight(150)
    arc(60, -math.pi / 2)   # tight right 90°
    straight(200)
    arc(60, +math.pi / 2)   # tight left 90°
    straight(150)
    arc(50, -math.pi / 3)   # S-bend: right 60°
    arc(50, +math.pi / 3)   # S-bend: left 60°
    straight(250)
    arc(40, +math.pi)       # tight 180° hairpin left
    straight(350)

    lat = lon = dist = 0.0
    pts = [{"lat": 0.0, "lon": 0.0, "elevation": round(elevation_fn(0.0), 4)}]
    for h in headings:
        lat  += step * math.sin(h)
        lon  += step * math.cos(h)
        dist += step
        pts.append({"lat": round(lat, 4), "lon": round(lon, 4),
                    "elevation": round(elevation_fn(dist), 4)})

    actual_m = len(headings) * step
    print(f"  {'(technical)':45s}  {len(pts)} pts  {actual_m:.0f} m")
    return pts


def _steep_downhill_hairpin_elev(d):
    hairpin_start = 1830.0
    hairpin_end   = 1960.0
    total         = 2010.0
    if d < 400.0:
        return 0.0
    if d < hairpin_start:
        return -100.0 * (d - 400.0) / (hairpin_start - 400.0)
    if d < hairpin_end:
        return -100.0 - 20.0 * (d - hairpin_start) / (hairpin_end - hairpin_start)
    return -120.0


print("\nGenerating technical tracks:")

save_hairpin("rl-2k-technical.json",
             build_technical_track(step=10.0))

save_hairpin("rl-2k-technical-hills.json",
             build_technical_track(step=10.0,
                                   elevation_fn=lambda d: 40.0 * math.sin(math.pi * d / 1800.0)))

save_hairpin("rl-2k-technical-downhill-hairpin.json",
             build_technical_track(step=10.0, elevation_fn=_steep_downhill_hairpin_elev))

print("Done.")

# ── Switchback stress-test ────────────────────────────────────────────────────

def build_switchback_track(step=10.0, elevation_fn=None):
    """
    ~2 km boids stress-test: tight 180° switchbacks (r=20 m) that break fixed
    boids parameters.  Fixed centering/matching factors cause the swarm to
    overshoot or scatter on rapid direction reversals; the RL agent must learn
    to reduce matching_factor through the turns.

    Layout (all distances approximate):
      straight(150) → double chicane (4 × 90° at r=20 m) → straight(50) →
      6 switchback pairs (12 × 180° hairpins at r=20 m, 60 m straights between)
      → straight(230)

    The zigzag pattern drifts progressively in the +lat direction so the path
    never crosses itself.
    """
    if elevation_fn is None:
        elevation_fn = lambda d: 0.0

    headings = []
    heading = 0.0

    def straight(length):
        n = max(1, round(length / step))
        headings.extend([heading] * n)

    def arc(radius, delta):
        nonlocal heading
        n = max(2, round(abs(delta) * radius / step))
        for k in range(1, n + 1):
            headings.append(heading + delta * k / n)
        heading += delta

    straight(150)

    # Double chicane: two S-pairs warm up boids for tight turns
    arc(20, -math.pi / 2)   # chicane 1: right 90°
    arc(20, +math.pi / 2)   # chicane 1: left 90° (back to straight)
    straight(20)
    arc(20, +math.pi / 2)   # chicane 2: left 90°
    arc(20, -math.pi / 2)   # chicane 2: right 90° (back to straight)

    straight(150)

    # 6 switchback pairs: right 180° → straight → left 180° → straight
    for _ in range(6):
        arc(20, -math.pi)   # hairpin right
        straight(40)
        arc(20, +math.pi)   # hairpin left
        straight(100)

    lat = lon = dist = 0.0
    pts = [{"lat": 0.0, "lon": 0.0, "elevation": round(elevation_fn(0.0), 4)}]
    for h in headings:
        lat  += step * math.sin(h)
        lon  += step * math.cos(h)
        dist += step
        pts.append({"lat": round(lat, 4), "lon": round(lon, 4),
                    "elevation": round(elevation_fn(dist), 4)})

    actual_m = len(headings) * step
    print(f"  {'(switchback)':45s}  {len(pts)} pts  {actual_m:.0f} m")
    return pts


def _switchback_downhill_elev(d):
    """
    Flat opening (150 m) → descent through the switchbacks → partial recovery.
    Grade peaks at ~12 % through the tightest turns (~750–1780 m).
    """
    descent_start = 150.0
    descent_end   = 2010.0
    total         = 2010.0
    if d < descent_start:
        return 0.0
    if d < descent_end:
        t = (d - descent_start) / (descent_end - descent_start)
        return -120.0 * math.sin(math.pi * t / 2.0)
    return -120.0 + 60.0 * (d - descent_end) / (total - descent_end)


print("\nGenerating switchback tracks:")

save_hairpin("rl-2k-switchback.json",
             build_switchback_track(step=10.0))

save_hairpin("rl-2k-switchback-downhill.json",
             build_switchback_track(step=10.0, elevation_fn=_switchback_downhill_elev))

print("Done.")

# ── Hairpin tracks ────────────────────────────────────────────────────────────
print("\nGenerating hairpin tracks:")

save_hairpin("rl-2k-hairpin.json",
             build_hairpin_track(step=10.0, hairpin_radius=40.0))

save_hairpin("rl-2k-hairpin-uphill.json",
             build_hairpin_track(step=10.0, hairpin_radius=40.0,
                                 elevation_fn=lambda d: d * 200.0 / 5000.0))

print("Done.")

# ── Downhill left-right track ─────────────────────────────────────────────────

def build_downhill_lr_track(step=10.0, elevation_fn=None):
    """
    Downhill straight → hard 90° left → downhill straight →
    hard 90° right → downhill straight.
    Uses r=25 m corners for a tight, realistic mountain descent.
    """
    if elevation_fn is None:
        elevation_fn = lambda d: 0.0

    headings = []
    heading = 0.0

    def straight(length):
        nonlocal heading
        n = max(1, round(length / step))
        headings.extend([heading] * n)

    def arc(radius, delta):
        nonlocal heading
        n = max(2, round(abs(delta) * radius / step))
        for k in range(1, n + 1):
            headings.append(heading + delta * k / n)
        heading += delta

    straight(350)
    arc(25, +math.pi / 2)   # hard 90° left
    straight(400)
    arc(25, -math.pi / 2)   # hard 90° right
    straight(400)

    lat = lon = dist = 0.0
    pts = [{"lat": 0.0, "lon": 0.0, "elevation": round(elevation_fn(0.0), 4)}]
    for h in headings:
        lat  += step * math.sin(h)
        lon  += step * math.cos(h)
        dist += step
        pts.append({"lat": round(lat, 4), "lon": round(lon, 4),
                    "elevation": round(elevation_fn(dist), 4)})

    actual_m = len(headings) * step
    print(f"  {'(downhill-lr)':45s}  {len(pts)} pts  {actual_m:.0f} m")
    return pts


print("\nGenerating downhill left-right track:")

# ~1230 m total, drops 120 m → ~10 % average grade
save_hairpin("rl-2k-downhill-left-right.json",
             build_downhill_lr_track(step=10.0,
                                     elevation_fn=lambda d: -d * 120.0 / 1230.0))

print("Done.")

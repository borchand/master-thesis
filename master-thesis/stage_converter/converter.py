import os
import json
import gpxpy

BASE_DIR = "master-thesis/stage_converter" 
INPUT_DIR = os.path.join(BASE_DIR, "input_files")
STAGES_DIR = os.path.join(BASE_DIR, "stages")

os.makedirs(STAGES_DIR, exist_ok=True)

def gpx_to_points(gpx_path: str):
    with open(gpx_path, "r", encoding="utf-8") as f:
        gpx = gpxpy.parse(f)

    points = []

    # Tracks
    for track in gpx.tracks:
        for segment in track.segments:
            for p in segment.points:
                points.append({
                    "lat": p.latitude,
                    "lon": p.longitude,
                    "elevation": p.elevation
                })

    for route in gpx.routes:
        for p in route.points:
            points.append({
                "lat": p.latitude,
                "lon": p.longitude,
                "elevation": p.elevation
            })

    return points


for name in os.listdir(INPUT_DIR):
    if not name.lower().endswith(".gpx"):
        skipped += 1
        continue

    gpx_path = os.path.join(INPUT_DIR, name)
    if not os.path.isfile(gpx_path):
        skipped += 1
        continue

    points = gpx_to_points(gpx_path)

    out_name = os.path.splitext(name)[0] + ".json"
    out_path = os.path.join(STAGES_DIR, out_name)

    with open(out_path, "w", encoding="utf-8") as out:
        json.dump(points, out, indent=2)
import os
import json
import gpxpy
from pyproj import Transformer

INPUT_DIR = os.path.join("stage_converter", "input_files")
STAGES_DIR = os.path.join("master-thesis", "stages")

os.makedirs(STAGES_DIR, exist_ok=True)

def gpx_to_points(gpx_path: str):
    with open(gpx_path, "r", encoding="utf-8") as f:
        gpx = gpxpy.parse(f)

    points = []

    for track in gpx.tracks:
        for segment in track.segments:
            for i, p in enumerate(segment.points):
                transformer = Transformer.from_crs("EPSG:4326", "EPSG:32633", always_xy=True)
                lon, lat = transformer.transform(p.longitude, p.latitude)
                if i == 0:
                    null_point = {
                        "lat": lat,
                        "lon": lon,
                        "elevation": p.elevation
                    }
                points.append({
                    "lat": (lat - null_point["lat"]),
                    "lon": (lon - null_point["lon"]),
                    "elevation": p.elevation - null_point["elevation"]
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
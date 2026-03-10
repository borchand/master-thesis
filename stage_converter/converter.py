import os
import json
import gpxpy
import math
from pyproj import Transformer

INPUT_DIR = os.path.join("stage_converter", "input_files")
STAGES_DIR = os.path.join("master-thesis", "stages")

os.makedirs(STAGES_DIR, exist_ok=True)

def gpx_to_points(gpx_path):
    with open(gpx_path, "r", encoding="utf-8") as f:
        gpx = gpxpy.parse(f)

    points = []
    lastPoint = {                        
        "lat": 0,
        "lon": 0,
        "elevation": 0}

    for track in gpx.tracks:
        for segment in track.segments:
            for i, p in enumerate(segment.points):
                transformer = Transformer.from_crs("EPSG:4326", "EPSG:32633", always_xy=True)
                lon, lat = transformer.transform(p.longitude, p.latitude)
                ele = (p.elevation if p.elevation else lastPoint["elevation"])

                if i == 0:
                    null_point = {
                        "lat": lat,
                        "lon": lon,
                        "elevation": ele
                    }
                    lastPoint = null_point
                
                #calculate if the gradiant is to large.
                chage_in_ele = ele-lastPoint["elevation"]
                if chage_in_ele != 0:
                    change_in_lat = lat-lastPoint["lat"]
                    change_in_lon = lon-lastPoint["lon"]
                    horizontal_distance = math.sqrt(change_in_lat**2 + change_in_lon**2)
                    gradient_rad = math.atan2(chage_in_ele, horizontal_distance)
                    if gradient_rad > 0.6981 or gradient_rad < -0.6981: #a drop or increase of 40 degree. higest ever in TTF 30 degree ish
                        continue

                points.append({
                    "lat": (lat - null_point["lat"]),
                    "lon": (lon - null_point["lon"]),
                    "elevation": ele - null_point["elevation"]
                })
                lastPoint = {
                        "lat": lat,
                        "lon": lon,
                        "elevation": ele
                    }
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
using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BikePath : Path3D
{
    [Export] public string RouteFilePath { get; set; } = "res://stages/rl-5k-hairpin.json";
    [Export] public string RlRouteFilePath { get; set; } = "res://stages/rl-5k-straight-flat.json";

    private static System.Collections.Generic.Dictionary<string, Curve3D> _curveCache = new();

    public override void _Ready()
    {
        Curve.ClearPoints();
        LoadCoords();
    }

    public void ReloadForRl()
    {
        RouteFilePath = RlRouteFilePath;
        Curve = (Curve3D)GetCachedCurve(RlRouteFilePath).Duplicate();
    }

    public void PreloadTracks(string[] paths)
    {
        foreach (string path in paths)
            GetCachedCurve(path);
    }

    private Curve3D GetCachedCurve(string path)
    {
        if (!_curveCache.ContainsKey(path))
        {
            var c = new Curve3D();
            foreach (var p in ParseTrackPoints(path))
                c.AddPoint(p);
            c.GetBakedLength();
            _curveCache[path] = c;
        }
        return _curveCache[path];
    }

    private System.Collections.Generic.List<Vector3> ParseTrackPoints(string path)
    {
        var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError("Could not open track file: " + path);
            return new System.Collections.Generic.List<Vector3>();
        }

        var data = Json.ParseString(file.GetAsText()).AsGodotArray();
        var points = new System.Collections.Generic.List<Vector3>();

        foreach (var entry in data)
        {
            var dict = entry.AsGodotDictionary();
            float lat = (float)dict["lat"];
            float elevation = (float)dict["elevation"];
            float lon = (float)dict["lon"];
            var v = new Vector3(lat, elevation, lon);

            int n = points.Count;
            if (n > 0)
            {
                if (v.DistanceTo(points[n - 1]) < 0.1f)
                    continue;

                if (n > 1)
                {
                    var dir1 = (points[n - 1] - points[n - 2]).Normalized();
                    var dir2 = (v - points[n - 1]).Normalized();
                    if (dir1.Dot(dir2) > 0.99f)
                    {
                        points[n - 1] = v;
                        continue;
                    }
                }
            }
            points.Add(v);
        }

        return points;
    }

    public void LoadCoords()
    {
        var file = FileAccess.Open(RouteFilePath, FileAccess.ModeFlags.Read);
        if (file == null)
        {
            GD.PushError("Could not open track file: " + RouteFilePath);
            return;
        }

        var data = Json.ParseString(file.GetAsText()).AsGodotArray();
        int i = 0;

        foreach (var entry in data)
        {
            var dict = entry.AsGodotDictionary();
            float lat = (float)dict["lat"];
            float lon = (float)dict["lon"];
            float elevation = (float)dict["elevation"];
            var vectorPoint = new Vector3(lat, elevation, lon);

            if (i > 0)
            {
                var prevPoint = Curve.GetPointPosition(i - 1);
                if (vectorPoint.DistanceTo(prevPoint) < 0.1f)
                    continue;

                if (i > 1)
                {
                    var prevPrevPoint = Curve.GetPointPosition(i - 2);
                    var dir1 = (prevPoint - prevPrevPoint).Normalized();
                    var dir2 = (vectorPoint - prevPoint).Normalized();
                    if (dir1.Dot(dir2) > 0.99f)
                    {
                        Curve.SetPointPosition(i - 1, vectorPoint);
                        continue;
                    }
                }
            }

            Curve.AddPoint(vectorPoint);
            i++;
        }
    }
}

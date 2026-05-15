using Godot;
using Godot.Collections;

[GlobalClass]
public partial class Drone : RigidBody3D
{
    private static int _nextId = 1;
    public int Id { get; private set; }

    public enum BoidMode { Boids, BoidsPriorityAttractionFields, BoidsPriorityGroups }

    public bool IsRl = false;
    public bool IsTraining = false;

    private int _collisionAtTimeStep = 0;
    private int _timestep = 1;

    private Camera3D _camera;
    public DroneCommunication DroneSensor { get; private set; }

    public Array CameraReadings { get; private set; } = new();
    public Array SensorReadingsDrones { get; private set; } = new();
    public Array SensorReadingsBikes { get; private set; } = new();

    public Variant TargetSpeed;
    public Variant TargetBike;

    [Export] public float BehindDistance = 4.0f;
    [Export] public float MaxTorque = 2.0f;
    [Export] public float YawGain = 2.2f;
    [Export] public float TorqueZone = 0.05f;
    [Export] public float MaxForce = 18.0f;

    [Export] public float MaxUpForce = 120.0f;
    [Export] public float YGain = 35.0f;
    [Export] public float YDamp = 18.0f;
    [Export] public float HeightOffset = 5.0f;
    [Export] public float AvoidRadius = 10.0f;
    [Export] public float AvoidFactor = 5.0f;
    [Export] public float CenteringFactor = 2.0f;
    [Export] public float MatchingFactor = 0.4f;

    [Export] public BoidMode DroneVersion = BoidMode.Boids;
    [Export] public float RandomSelectionRate = 0.2f;
    private readonly int _keepSelectionForNFrames = 100;

    [Export] public float ClusterDistanceThreshold = 10.0f;
    [Export] public float CoverageRadius = 10.0f;

    [Export] public bool DebugDraw = false;
    [Export] public float DebugLineWidth = 0.1f;

    private readonly System.Collections.Generic.List<MeshInstance3D> _debugBikeLines = new();
    private readonly System.Collections.Generic.List<MeshInstance3D> _debugClusterDots = new();
    private MeshInstance3D _debugClusterTargetLine;

    [Export] public bool IdleUntilNeeded = false;
    [Export] public bool HasActivated = true;

    private CustomLogger _logging;
    private DroneRegistry _droneRegistry;

    public override void _Ready()
    {
        Id = _nextId++;
        _camera = GetNode<Camera3D>("Camera3D");
        DroneSensor = GetNode<DroneCommunication>("Drone_communication");
        _logging = GetNode<CustomLogger>("/root/logging");
        _droneRegistry = GetNode<DroneRegistry>("/root/DroneRegistry");

        _droneRegistry.RegisterDrone(this);
        ContactMonitor = true;
        MaxContactsReported = 100;
        if (!IsTraining)
            StartLogging();
        BodyEntered += OnBodyEntered;
    }

    public override void _ExitTree()
    {
        _droneRegistry?.UnregisterDrone(this);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (IdleUntilNeeded && !HasActivated)
        {
            ReadSensor(GetDroneSet(), GetBikeSet());
            if (!ShouldActivateFromCoverage())
            {
                LinearVelocity = Vector3.Zero;
                AngularVelocity = Vector3.Zero;
                _timestep++;
                return;
            }
            HasActivated = true;
        }

        if (IsTraining)
            return;

        BoidsUpdate();
        LogInformation(_timestep);
        _timestep++;
        _collisionAtTimeStep = 0;
    }

    public void SetTunableParameters(Dictionary parameters)
    {
        AvoidRadius = (float)parameters["avoid_radius"];
        AvoidFactor = (float)parameters["avoid_factor"];
        CenteringFactor = (float)parameters["centering_factor"];
        MatchingFactor = (float)parameters["matching_factor"];
    }

    private Dictionary GetDroneSet() => DroneSensor.DroneSet;
    private Dictionary GetBikeSet() => DroneSensor.BikeSet;

    private void BoidsUpdate()
    {
        ReadSensor(GetDroneSet(), GetBikeSet());

        Array bikesForBoids;

        if (DroneVersion == BoidMode.BoidsPriorityAttractionFields)
        {
            var clusters = ClusterBikes(SensorReadingsBikes);
            var alignmentVec = PriorityAlignment(clusters);
            var cohesionVec = PriorityCohesion(clusters);
            DrawClusterDebugLines(clusters);
            ApplyBoids(new Array(), alignmentVec, cohesionVec);
            return;
        }
        else if (DroneVersion == BoidMode.BoidsPriorityGroups)
        {
            var clusters = ClusterBikes(SensorReadingsBikes);
            var assignedCluster = AssignedCluster(clusters);
            DrawClusterDebugLines(clusters);
            DrawBikeDebugLines((Array)assignedCluster["bikes"]);
            bikesForBoids = (Array)assignedCluster["bikes"];
        }
        else
        {
            DrawBikeDebugLines(SensorReadingsBikes);
            bikesForBoids = SensorReadingsBikes;
        }

        BoidsBikes(bikesForBoids);
    }

    public void BoidsBikes(Array bikes)
    {
        var alignmentVec = Alignment(bikes);
        var cohesionVec = Cohesion(bikes);
        ApplyBoids(bikes, alignmentVec, cohesionVec);
    }

    private void ApplyBoids(Array bikes, Vector3 alignmentVec, Vector3 cohesionVec)
    {
        var separationVec = Separation();
        var directionVec = alignmentVec + cohesionVec + separationVec;
        directionVec.Y = HeightForce(bikes);
        ApplyCentralForce(ClampVector(directionVec, MaxForce));
        RotateTowardsDirection(-alignmentVec);
    }

    private Vector3 Alignment(Array bikes)
    {
        var result = Vector3.Zero;
        int count = 0;

        foreach (Variant v in bikes)
        {
            var bike = (Dictionary)v;
            count++;
            result.X += ((Vector3)bike["velocity"]).X;
            result.Z += ((Vector3)bike["velocity"]).Z;
        }

        if (count > 0)
        {
            result.X /= count;
            result.Z /= count;
        }

        result.X = (result.X - LinearVelocity.X) * MatchingFactor;
        result.Z = (result.Z - LinearVelocity.Z) * MatchingFactor;
        return result;
    }

    private Vector3 Cohesion(Array bikes)
    {
        var result = Vector3.Zero;
        int count = 0;

        foreach (Variant v in bikes)
        {
            var bike = (Dictionary)v;
            count++;
            result.X += ((Vector3)bike["position"]).X;
            result.Z += ((Vector3)bike["position"]).Z;
        }

        if (count > 0)
        {
            result.X /= count;
            result.Z /= count;
            result.X -= GlobalPosition.X;
            result.Z -= GlobalPosition.Z;
            result.X *= CenteringFactor;
            result.Z *= CenteringFactor;
        }

        return result;
    }

    private Vector3 Separation()
    {
        var result = Vector3.Zero;

        foreach (Variant v in SensorReadingsDrones)
        {
            var reading = (Dictionary)v;
            if ((float)reading["distance"] > AvoidRadius)
                continue;

            var pos = (Vector3)reading["position"];
            var diff = new Vector3(GlobalPosition.X - pos.X, 0, GlobalPosition.Z - pos.Z);
            float dist = Mathf.Max(diff.Length(), 0.01f);
            result += diff / (dist * dist);
        }

        return result * AvoidFactor;
    }

    private float HeightForce(Array bikes)
    {
        if (bikes.Count == 0)
            return 0.0f;

        float highestY = float.NegativeInfinity;
        foreach (Variant v in bikes)
        {
            var bike = (Dictionary)v;
            highestY = Mathf.Max(highestY, ((Vector3)bike["position"]).Y);
        }

        float yError = (highestY + HeightOffset) - GlobalPosition.Y;
        return Mathf.Clamp(yError * YGain - LinearVelocity.Y * YDamp, -MaxUpForce, MaxUpForce);
    }

    private void RotateTowardsDirection(Vector3 dir)
    {
        var desiredForward = FlatDir(dir);
        if (desiredForward.Length() < 0.01f)
            return;

        var droneForward = FlatDir(-GlobalTransform.Basis.Z);
        var up = GlobalTransform.Basis.Y;
        float yawError = Mathf.Atan2(droneForward.Cross(desiredForward).Y, droneForward.Dot(desiredForward));

        if (Mathf.Abs(yawError) > TorqueZone)
            ApplyTorque(up * Mathf.Clamp(yawError * YawGain, -1.0f, 1.0f) * MaxTorque);
    }

    public Array ClusterBikes(Array readings)
    {
        var clusters = new Array();

        foreach (Variant rv in readings)
        {
            var bike = (Dictionary)rv;
            var bikePos = (Vector3)bike["position"];
            bool assigned = false;

            foreach (Variant cv in clusters)
            {
                var cluster = (Dictionary)cv;
                var centroid = (Vector3)cluster["centroid"];
                float flatDist = new Vector2(bikePos.X - centroid.X, bikePos.Z - centroid.Z).Length();

                if (flatDist < ClusterDistanceThreshold)
                {
                    float n = (float)(int)cluster["size"];
                    cluster["centroid"] = (centroid * n + bikePos) / (n + 1.0f);
                    cluster["velocity"] = ((Vector3)cluster["velocity"] * n + (Vector3)bike["velocity"]) / (n + 1.0f);
                    cluster["size"] = (int)cluster["size"] + 1;
                    ((Array)cluster["bikes"]).Add(bike);
                    assigned = true;
                    break;
                }
            }

            if (!assigned)
                clusters.Add(new Dictionary
                {
                    ["centroid"] = bikePos,
                    ["velocity"] = (Vector3)bike["velocity"],
                    ["size"] = 1,
                    ["bikes"] = new Array { bike }
                });
        }

        return clusters;
    }

    private Dictionary AssignedCluster(Array clusters)
    {
        if (clusters.Count == 0)
            return new Dictionary { ["centroid"] = Vector3.Zero, ["velocity"] = Vector3.Zero, ["size"] = 0, ["bikes"] = new Array() };

        Dictionary best = null;
        float bestVal = float.NegativeInfinity;

        foreach (Variant cv in clusters)
        {
            var cluster = (Dictionary)cv;
            float v = CoverageScore((int)cluster["size"]);
            float selfDist = GlobalPosition.DistanceTo((Vector3)cluster["centroid"]);

            int count = 0;
            foreach (Variant dv in SensorReadingsDrones)
            {
                var drone = (Dictionary)dv;
                float droneDist = ((Vector3)drone["position"]).DistanceTo((Vector3)cluster["centroid"]);
                if (droneDist < selfDist || droneDist < CoverageRadius)
                    count++;
            }

            var toCluster = (Vector3)cluster["centroid"] - GlobalPosition;
            toCluster.Y = 0;
            if (Mathf.Abs((-GlobalTransform.Basis.Z).AngleTo(toCluster)) > Mathf.Pi / 2)
                v *= 0.8f;

            v -= count;

            if (v > bestVal)
            {
                bestVal = v;
                best = cluster;
            }
        }

        return best;
    }

    private Vector3 PriorityCohesion(Array clusters)
    {
        if (clusters.Count == 0)
            return Vector3.Zero;
        var target = AssignedCluster(clusters);
        var toCentroid = (Vector3)target["centroid"] - GlobalPosition;
        toCentroid.Y = 0.0f;
        return toCentroid * CenteringFactor;
    }

    private Vector3 PriorityAlignment(Array clusters)
    {
        if (clusters.Count == 0)
            return Vector3.Zero;
        var target = AssignedCluster(clusters);
        return ((Vector3)target["velocity"] - FlatVelocity(LinearVelocity)) * MatchingFactor;
    }

    public MeshInstance3D MakeClusterDot()
    {
        var mi = new MeshInstance3D();
        mi.Mesh = new SphereMesh { Radius = 0.5f, Height = 1.0f };
        mi.MaterialOverride = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            NoDepthTest = true
        };
        return mi;
    }

    private bool ShouldActivateFromCoverage()
    {
        if (CameraReadings.Count == 0)
            return false;

        var clusters = ClusterBikes(CameraReadings);
        foreach (Variant cv in clusters)
        {
            var cluster = (Dictionary)cv;
            if (CountDronesCoveringCluster(cluster) < CoverageScore((int)cluster["size"]))
                return true;
        }
        return false;
    }

    private int CountDronesCoveringCluster(Dictionary cluster)
    {
        int count = 0;
        var centroid = (Vector3)cluster["centroid"];
        foreach (Variant dv in SensorReadingsDrones)
        {
            if (((Vector3)((Dictionary)dv)["position"]).DistanceTo(centroid) <= CoverageRadius)
                count++;
        }
        return count;
    }

    private void DrawClusterDebugLines(Array clusters)
    {
        if (!DebugDraw || clusters.Count == 0)
            return;

        while (_debugClusterDots.Count < clusters.Count)
        {
            var mi = MakeClusterDot();
            GetParent().CallDeferred(Node.MethodName.AddChild, mi);
            _debugClusterDots.Add(mi);
        }

        var assigned = AssignedCluster(clusters);
        for (int i = 0; i < clusters.Count; i++)
        {
            var cluster = (Dictionary)clusters[i];
            var mi = _debugClusterDots[i];
            ((StandardMaterial3D)mi.MaterialOverride).AlbedoColor =
                (Vector3)cluster["centroid"] == (Vector3)assigned["centroid"] ? Colors.Green : Colors.Orange;
            if (mi.IsInsideTree())
                mi.GlobalPosition = (Vector3)cluster["centroid"];
            mi.Visible = true;
        }
        for (int i = clusters.Count; i < _debugClusterDots.Count; i++)
            _debugClusterDots[i].Visible = false;

        _debugClusterTargetLine ??= MakeDebugLine();
        if (!_debugClusterTargetLine.IsInsideTree())
            GetParent().CallDeferred(Node.MethodName.AddChild, _debugClusterTargetLine);
        PlaceDebugLine(_debugClusterTargetLine, GlobalPosition, (Vector3)assigned["centroid"], Colors.Green);
    }

    public MeshInstance3D MakeDebugLine()
    {
        var mi = new MeshInstance3D();
        mi.Mesh = new BoxMesh { Size = new Vector3(DebugLineWidth, DebugLineWidth, 1.0f) };
        mi.MaterialOverride = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            NoDepthTest = true
        };
        return mi;
    }

    public void PlaceDebugLine(MeshInstance3D mi, Vector3 a, Vector3 b, Color color, Vector3? up = null)
    {
        if (!mi.IsInsideTree())
            return;
        var dir = b - a;
        float length = dir.Length();
        if (length < 0.001f) { mi.Visible = false; return; }
        mi.GlobalPosition = (a + b) * 0.5f;
        mi.GlobalTransform = new Transform3D(Basis.LookingAt(dir / length, up ?? Vector3.Up), mi.GlobalPosition);
        mi.Scale = new Vector3(1.0f, 1.0f, length);
        ((StandardMaterial3D)mi.MaterialOverride).AlbedoColor = color;
        mi.Visible = true;
    }

    private void DrawBikeDebugLines(Array bikes)
    {
        if (!DebugDraw)
            return;
        while (_debugBikeLines.Count < bikes.Count)
        {
            var mi = MakeDebugLine();
            GetParent().CallDeferred(Node.MethodName.AddChild, mi);
            _debugBikeLines.Add(mi);
        }
        for (int i = 0; i < bikes.Count; i++)
            PlaceDebugLine(_debugBikeLines[i], GlobalPosition, (Vector3)((Dictionary)bikes[i])["position"], Colors.Yellow);
        for (int i = bikes.Count; i < _debugBikeLines.Count; i++)
            _debugBikeLines[i].Visible = false;
    }

    private Vector3 FlatDir(Vector3 v) { v.Y = 0; return v.Normalized(); }
    private Vector3 FlatVelocity(Vector3 v) { v.Y = 0; return v; }
    private Vector3 ClampVector(Vector3 v, float maxLen) => v.Length() > maxLen ? v.Normalized() * maxLen : v;

    public Camera3D GetCameraNode() => _camera;

    public void ReadSensor(Dictionary drones, Dictionary bikes)
    {
        CameraReadings = new Array();
        SensorReadingsDrones = new Array();
        SensorReadingsBikes = new Array();

        foreach (Variant key in drones.Keys)
        {
            var drone = (Drone)(GodotObject)key;
            if (drone.Id == Id) continue;
            var pos = drone.GlobalPosition;
            SensorReadingsDrones.Add(new Dictionary
            {
                ["id"] = drone.Id,
                ["position"] = pos,
                ["distance"] = GlobalPosition.DistanceTo(pos),
                ["direction"] = GlobalPosition.DirectionTo(pos)
            });
        }

        foreach (Variant key in bikes.Keys)
        {
            var bike = (BikeBody)(GodotObject)key;
            var data = GetBikeData(bike);
            if (_camera.IsPositionInFrustum(bike.GlobalPosition))
                CameraReadings.Add(data);
            SensorReadingsBikes.Add(data);
        }
    }

    private Dictionary GetBikeData(BikeBody bike)
    {
        var bikePos = bike.GlobalPosition;
        var parentSpeed = (float)bike.GetParent().Get("speed");
        return new Dictionary
        {
            ["position"] = bikePos,
            ["distance"] = GlobalPosition.DistanceTo(bikePos),
            ["direction"] = GlobalPosition.DirectionTo(bikePos),
            ["velocity"] = FlatDir(-bike.GlobalTransform.Basis.Z) * parentSpeed,
            ["id"] = bike.BikeId
        };
    }

    public int CoverageScore(int n) =>
        Mathf.RoundToInt(Mathf.Log(n) / Mathf.Log(1.9f)) + 1;

    private void OnBodyEntered(Node body) => _collisionAtTimeStep++;

    private Array CreateLoggingMessage(int delta)
    {
        var data = new Array
        {
            delta.ToString(),
            GlobalPosition.X.ToString(),
            GlobalPosition.Y.ToString(),
            GlobalPosition.Z.ToString(),
            _collisionAtTimeStep.ToString()
        };

        var bikesId = "[";
        foreach (Variant v in CameraReadings)
            bikesId += " " + ((Dictionary)v)["id"].ToString();
        data.Add(bikesId + " ]");

        return data;
    }

    private void StartLogging() => _logging.StartRunFile(Id.ToString(), "drone");

    private void LogInformation(int delta) =>
        _logging.AppendLine(Id.ToString(), "drone", CreateLoggingMessage(delta));
}

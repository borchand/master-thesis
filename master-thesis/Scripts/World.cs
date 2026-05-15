using Godot;
using Godot.Collections;

[GlobalClass]
public partial class World : Node3D
{
    private static readonly PackedScene _bikeScene = GD.Load<PackedScene>("res://Scenes/Bike/Bike.tscn");
    private static readonly PackedScene _droneScene = GD.Load<PackedScene>("res://Scenes/Drone/Drone.tscn");

    [Export] public bool IsTraining = false;
    [Export] public bool IsRl = false;

    [Export] public int MinBikeCount = 1;
    [Export] public int MaxBikeCount = 20;
    [Export] public int[] DroneCountsPerInstance = { 1, 2, 8, 15 };

    private static readonly string[] RlTracks =
    {
        "res://stages/rl-5k-straight-flat.json",
        "res://stages/rl-5k-straight-uphill.json",
        "res://stages/rl-5k-straight-downhill.json",
        "res://stages/rl-5k-rolling-hills.json",
        "res://stages/rl-5k-valley.json",
        "res://stages/rl-5k-mountain.json",
        "res://stages/rl-5k-left-arc.json",
        "res://stages/rl-5k-right-arc.json",
        "res://stages/rl-5k-s-curve.json",
        "res://stages/rl-5k-zigzag.json",
        "res://stages/rl-5k-left-arc-uphill.json",
        "res://stages/rl-5k-right-arc-downhill.json",
        "res://stages/rl-5k-s-curve-uphill.json",
        "res://stages/rl-5k-rolling-left-arc.json",
        "res://stages/rl-5k-hairpin.json",
        "res://stages/rl-5k-hairpin-uphill.json",
    };

    private BikePath _pathInstance;

    public Godot.Collections.Array<Drone> DroneList { get; } = new();

    public int InstanceId { get; private set; } = -1;

    private int _bikeCount = 180;
    private int _droneCount = 0;

    [Export] public float DroneSpawnSpacing = 1.5f;
    [Export] public bool PlaceDroneAlongRoad = false;

    private CustomLogger _logging = null;
    private SharedState _shared = null;

    public override void _Ready()
    {
        _pathInstance = GetNode<BikePath>("BikePath3d");
        _logging = GetNode<CustomLogger>("/root/logging");
        _shared = GetNode<SharedState>("/root/shared");

        if (!IsTraining)
            _logging.AddInfo(_bikeCount, _droneCount, _pathInstance.RouteFilePath, _shared.DroneCommunicationSize);

        InstanceId = _shared.RegisterInstance();

        if (IsRl && IsTraining)
        {
            _pathInstance.PreloadTracks(RlTracks);
            RandomizeTrack();
            _bikeCount = (int)GD.RandRange(MinBikeCount, MaxBikeCount);
            if (InstanceId < DroneCountsPerInstance.Length)
                _droneCount = DroneCountsPerInstance[InstanceId];
        }

        if (IsTraining)
        {
            GetNode<Control>("Menu/ToggleContainer").Visible = false;
            GetNode<Control>("Menu/OtherContainer").Visible = false;
            GetNode<Control>("Menu").OffsetBottom = 60.0f;
        }

        for (int i = 0; i < _bikeCount; i++)
            AddBike();
        for (int i = 0; i < _droneCount; i++)
            AddDrone(false);

        if (PlaceDroneAlongRoad)
        {
            PlaceAllDrones();
        }
        else
        {
            var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
            for (int i = 0; i < DroneList.Count; i++)
            {
                int bikeIndex = i % bikeList.Count;
                PlaceDrone(DroneList[i], bikeIndex);
            }
        }

        GetNode<Range>("Menu/OtherContainer/FollowDroneInPos").MaxValue = _droneCount - 1;
        GetNode<Range>("Menu/OtherContainer/FollowBikeInPos").MaxValue = _bikeCount - 1;
    }

    public void AddDrone(bool autoPlace = true)
    {
        var droneInstance = _droneScene.Instantiate<Drone>();
        droneInstance.IsRl = IsRl;
        droneInstance.IsTraining = IsTraining;
        var droneCamera = droneInstance.GetNode<Camera3D>("Camera3D");
        ((Godot.Collections.Array)_shared.DroneCameraLists[InstanceId]).Add(droneCamera);
        AddChild(droneInstance);
        DroneList.Add(droneInstance);
        if (autoPlace)
        {
            var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
            int bikeIndex = (DroneList.Count - 1) % bikeList.Count;
            PlaceDrone(droneInstance, bikeIndex);
        }
    }

    public void PlaceAllDrones()
    {
        int total = DroneList.Count;
        int routeDroneCount = (int)Mathf.Floor((float)total / 3.0f);
        int normalDroneCount = total - routeDroneCount;
        var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
        for (int i = 0; i < total; i++)
        {
            if (i >= normalDroneCount)
            {
                int routeIndex = i - normalDroneCount;
                PlaceDroneAlongMiddleSection(DroneList[i], routeIndex, routeDroneCount);
            }
            else
            {
                int bikeIndex = i % bikeList.Count;
                PlaceDrone(DroneList[i], bikeIndex);
            }
        }
    }

    public void PlaceDrone(Drone droneInstance, int bikeIndex)
    {
        var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
        var _bike = (Bike)(GodotObject)bikeList[bikeIndex];
        var bikeForward = -_bike.GlobalTransform.Basis.Z;
        bikeForward.Y = 0;
        bikeForward = bikeForward.Normalized();
        var desiredPos = _bike.GlobalPosition - bikeForward * droneInstance.BehindDistance;
        desiredPos.Y = _bike.GlobalPosition.Y + droneInstance.HeightOffset;
        int droneIndex = DroneList.IndexOf(droneInstance);
        int total = DroneList.Count;
        float spacing = DroneSpawnSpacing;
        int cols = Mathf.Max(1, Mathf.CeilToInt(Mathf.Sqrt((float)total)));
        int row = droneIndex / cols;
        int col = droneIndex % cols;
        int colsInRow = Mathf.Min(cols, total - row * cols);
        var bikeRight = bikeForward.Cross(Vector3.Up).Normalized();
        desiredPos += bikeRight * (col - (colsInRow - 1) * 0.5f) * spacing;
        desiredPos -= bikeForward * row * spacing;
        droneInstance.Position = desiredPos;
    }

    public void PlaceDroneAlongMiddleSection(Drone droneInstance, int routeIndex, int routeDroneCount)
    {
        var curve = _pathInstance.Curve;
        float length = curve.GetBakedLength();
        float startOffset = length / 4.0f;
        float endOffset = length * 3.0f / 4.0f;
        float t = 0.5f;
        if (routeDroneCount > 1)
            t = (float)routeIndex / (float)(routeDroneCount - 1);
        float offset = Mathf.Lerp(startOffset, endOffset, t);
        var localRoadPos = curve.SampleBaked(offset);
        var roadWorldPos = _pathInstance.ToGlobal(localRoadPos);
        float aheadOffset = Mathf.Min(offset + 5.0f, length);
        var aheadLocalPos = curve.SampleBaked(aheadOffset);
        var aheadWorldPos = _pathInstance.ToGlobal(aheadLocalPos);
        var roadDirection = aheadWorldPos - roadWorldPos;
        roadDirection.Y = 0;
        roadDirection = roadDirection.Normalized();
        var sideDirection = new Vector3(-roadDirection.Z, 0, roadDirection.X).Normalized();
        var droneWorldPos = roadWorldPos + sideDirection * 25;
        droneWorldPos.Y += droneInstance.HeightOffset;
        droneInstance.GlobalPosition = droneWorldPos;
        var lookTarget = roadWorldPos;
        lookTarget.Y = droneWorldPos.Y;
        droneInstance.LookAt(lookTarget, Vector3.Up);
        droneInstance.IdleUntilNeeded = true;
        droneInstance.HasActivated = false;
    }

    public void AddBike()
    {
        int wattSpread = 9;
        var bikeInstance = _bikeScene.Instantiate<Bike>();
        bikeInstance.FreeingBike += BikeFreed;
        bikeInstance.IsRl = IsRl;
        bikeInstance.IsTraining = IsTraining;
        var rng = new RandomNumberGenerator();
        int randomWattVariant = wattSpread * rng.RandiRange(-1, 2);
        bikeInstance.SetWatts(373 + randomWattVariant, 573 + randomWattVariant);
        _pathInstance.AddChild(bikeInstance);
        bikeInstance.Progress = (randomWattVariant / 2) + rng.RandfRange(0.0f, 2.0f);
        ((Godot.Collections.Array)_shared.BikeLists[InstanceId]).Add(bikeInstance);
    }

    private void BikeFreed(Bike freedBike)
    {
        var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
        bikeList.Remove(Variant.From(freedBike));
        if (bikeList.Count == 0 && !IsTraining)
            GetTree().Quit();
    }

    public void ResetTrackAndBikeAndDrone()
    {
        var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
        var bikesToFree = bikeList.Duplicate();
        foreach (var v in bikesToFree)
            ((Bike)(GodotObject)v).SafeQueueFree();

        ulong time = Time.GetTicksMsec();
        RandomizeTrack();
        GD.Print("Track randomization took ", Time.GetTicksMsec() - time, " ms");
        _bikeCount = (int)GD.RandRange(MinBikeCount, MaxBikeCount);
        for (int i = 0; i < _bikeCount; i++)
            AddBike();
        PlaceAllDrones();
    }

    public void RespawnDrone(Drone droneInstance)
    {
        var bikeList = (Godot.Collections.Array)_shared.BikeLists[InstanceId];
        if (bikeList.Count == 0)
            return;
        int bikeIndex = (int)GD.Randi() % bikeList.Count;
        PlaceDrone(droneInstance, bikeIndex);
    }

    private void RandomizeTrack()
    {
        string track = RlTracks[(int)GD.Randi() % RlTracks.Length];
        _pathInstance.RlRouteFilePath = track;
        _pathInstance.ReloadForRl();
    }
}

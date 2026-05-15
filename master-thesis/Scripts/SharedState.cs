using Godot;
using Godot.Collections;

[GlobalClass]
public partial class SharedState : Node
{
    public bool Paused = false;
    public bool FreeRoam = false;
    public bool FollowDrone = false;
    public bool DroneControlled = false;
    public bool FollowBike = false;
    public int FollowBikeInPos = 0;
    public Godot.Collections.Array BikeLists = new();
    public Godot.Collections.Array DroneCameraLists = new();
    public int DroneCommunicationSize = 60;
    public int FollowedDroneIndex = 0;

    public int RegisterInstance()
    {
        BikeLists.Add(new Godot.Collections.Array());
        DroneCameraLists.Add(new Godot.Collections.Array());
        return BikeLists.Count - 1;
    }

    public float GetProgressRatioOfBikeInPos(int pos, int instanceId)
    {
        var bikes = BikeLists[instanceId].AsGodotArray();
        if (bikes.Count == 0)
            return 1.0f;

        var bikeProgress = new System.Collections.Generic.List<float>();
        foreach (var v in bikes)
        {
            var bike = (Bike)(GodotObject)v;
            bikeProgress.Add(bike.ProgressRatio);
        }

        bikeProgress.Sort((a, b) => b.CompareTo(a));
        return bikeProgress[pos];
    }

    public Camera3D GetCameraOfBikeInPos(int pos, int instanceId)
    {
        var bikes = BikeLists[instanceId].AsGodotArray();

        var bikeProgress = new System.Collections.Generic.List<(float Progress, Camera3D Camera)>();
        foreach (var v in bikes)
        {
            var bike = (Bike)(GodotObject)v;
            bikeProgress.Add((bike.Progress, bike.GetCameraNode()));
        }

        bikeProgress.Sort((a, b) => b.Progress.CompareTo(a.Progress));

        if (pos >= bikeProgress.Count)
            pos = bikeProgress.Count - 1;

        return bikeProgress[pos].Camera;
    }

    public void ToggleFreeRoam()
    {
        FreeRoam = !FreeRoam;
        if (FreeRoam)
            Input.SetMouseMode(Input.MouseModeEnum.Hidden);
        else
            Input.SetMouseMode(Input.MouseModeEnum.Visible);
    }

    public void Pause()
    {
        Paused = !Paused;
        GetTree().Paused = Paused;
    }

    public void ToggleDrone()
    {
        FollowBike = false;
        FollowDrone = !FollowDrone;
    }

    public void ToggleBike()
    {
        FollowDrone = false;
        DroneControlled = false;
        FollowBike = !FollowBike;
    }
}

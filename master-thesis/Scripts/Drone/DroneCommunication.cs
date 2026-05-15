using Godot;
using Godot.Collections;

[GlobalClass]
public partial class DroneCommunication : Node3D
{
    public Dictionary DroneSet { get; } = new();
    public Dictionary BikeSet { get; } = new();

    private GodotObject _shared;
    private DroneRegistry _droneRegistry;

    public override void _Ready()
    {
        _shared = GetNode<GodotObject>("/root/shared");
        _droneRegistry = GetNode<DroneRegistry>("/root/DroneRegistry");
    }

    public override void _PhysicsProcess(double delta)
    {
        var origin = GetParent<Node3D>().GlobalPosition;
        float radius = (float)_shared.Get("drone_communication_size");

        DroneSet.Clear();
        BikeSet.Clear();

        foreach (var drone in _droneRegistry.DroneList)
            if (drone.GlobalPosition.DistanceTo(origin) <= radius)
                DroneSet[drone] = drone;

        foreach (var bike in _droneRegistry.BikeList)
            if (bike.GlobalPosition.DistanceTo(origin) <= radius)
                BikeSet[bike] = bike;
    }
}

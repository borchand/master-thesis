using Godot;
using System.Collections.Generic;

[GlobalClass]
public partial class DroneCommunication : Node3D
{
    public List<Drone> DroneListFiltered { get; } = new();
    public List<BikeBody> BikeListFiltered { get; } = new();

    private SharedState _shared;
    private DroneRegistry _droneRegistry;

    public override void _Ready()
    {
        _shared = GetNode<SharedState>("/root/shared");
        _droneRegistry = GetNode<DroneRegistry>("/root/DroneRegistry");
    }

    public override void _PhysicsProcess(double delta)
    {
        var origin = GetParent<Node3D>().GlobalPosition;
        float radius = _shared.DroneCommunicationSize;

        DroneListFiltered.Clear();
        BikeListFiltered.Clear();

        foreach (var drone in _droneRegistry.DroneList)
            if (drone.GlobalPosition.DistanceTo(origin) <= radius)
                DroneListFiltered.Add(drone);

        foreach (var bike in _droneRegistry.BikeList)
            if (bike.GlobalPosition.DistanceTo(origin) <= radius)
                BikeListFiltered.Add(bike);
    }
}

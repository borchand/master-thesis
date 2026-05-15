using Godot;
using Godot.Collections;
using System.Collections.Generic;

[GlobalClass]
public partial class DroneRegistry : Node
{
    public Dictionary Drones { get; } = new();
    public Dictionary Bikes { get; } = new();

    // C# lists for allocation-free iteration from C# code
    public List<Drone> DroneList { get; } = new();
    public List<BikeBody> BikeList { get; } = new();

    public void RegisterDrone(Drone drone)
    {
        Drones[drone] = drone;
        DroneList.Add(drone);
    }

    public void UnregisterDrone(Drone drone)
    {
        Drones.Remove(drone);
        DroneList.Remove(drone);
    }

    public void RegisterBike(BikeBody bike)
    {
        Bikes[bike] = bike;
        BikeList.Add(bike);
    }

    public void UnregisterBike(BikeBody bike)
    {
        Bikes.Remove(bike);
        BikeList.Remove(bike);
    }
}

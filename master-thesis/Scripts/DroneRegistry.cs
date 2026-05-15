using Godot;
using Godot.Collections;

[GlobalClass]
public partial class DroneRegistry : Node
{
    public Dictionary Drones { get; } = new();
    public Dictionary Bikes { get; } = new();

    public void RegisterDrone(Drone drone) => Drones[drone] = drone;
    public void UnregisterDrone(Drone drone) => Drones.Remove(drone);

    public void RegisterBike(BikeBody bike) => Bikes[bike] = bike;
    public void UnregisterBike(BikeBody bike) => Bikes.Remove(bike);
}

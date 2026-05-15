using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BikeBody : StaticBody3D
{
    private static int _nextId = 1;
    public int BikeId { get; private set; }
    public Bike ParentBike { get; private set; }
    private int _timestep = 1;

    private CustomLogger _logging;
    private DroneRegistry _droneRegistry;

    public override void _Ready()
    {
        BikeId = _nextId++;
        ParentBike = GetParent<Bike>();
        AddToGroup("bikes");

        _logging = GetNode<CustomLogger>("/root/logging");
        _droneRegistry = GetNode<DroneRegistry>("/root/DroneRegistry");
        _droneRegistry.RegisterBike(this);

        if (!GetParentIsTraining())
            StartLogging();
    }

    public override void _ExitTree()
    {
        _droneRegistry?.UnregisterBike(this);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!GetParentIsTraining())
            LogInformation(_timestep);
        _timestep++;
    }

    private bool GetParentIsTraining() => (bool)GetParent().Get("is_training");

    private Array CreateLoggingMessage(int delta) => new()
    {
        delta.ToString(),
        GlobalPosition.X.ToString(),
        GlobalPosition.Y.ToString(),
        GlobalPosition.Z.ToString(),
    };

    private void StartLogging() => _logging.StartRunFile(BikeId.ToString(), "bike");

    private void LogInformation(int delta) =>
        _logging.AppendLine(BikeId.ToString(), "bike", CreateLoggingMessage(delta));
}

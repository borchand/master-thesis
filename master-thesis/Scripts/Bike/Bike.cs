using Godot;
using Godot.Collections;

[GlobalClass]
public partial class Bike : PathFollow3D
{
    [Signal]
    public delegate void FreeingBikeEventHandler(Bike bike);

    private record struct PelotonResult(int NBikes, float AvgDist, float? DistTo1st, float? DistTo3rd);

    private BikeBody _bikebody;
    private DroneRegistry _droneRegistry;
    private readonly System.Collections.Generic.List<float> _aheadDistances = new(16);

    private enum BikeState { Cruise, Attack }

    private RandomNumberGenerator _rng = new RandomNumberGenerator();
    private float _maxProgress;
    private Camera3D _camera;

    public int PrSecChecks = 4;
    private float _timerThreshold;
    private float _timer = 0f;
    private float _totalTime = 0f;

    public bool IsRl = false;
    public bool IsTraining = false;

    public float Speed = 9.0f;
    private int _speedUpProbability = 12;
    private int _speedDownProbability = 7;
    private float _acceleration = 0.0f;

    private float _sustainableWatt = 0f;
    private float _initialBreakoutWatt = 0f;
    private float _aFatigueResistence = 0.00003f;
    private float _fatigueThreashold = 52800.0f;
    private float _bStaminaDegresse = 0.0000002f;
    private float _fatigue = 0f;
    private bool _inPeloton = false;
    private BikeState _behavior = BikeState.Cruise;

    private float _cohesionC = 0.8f;
    private float _separationC = 0.05f;

    public override void _Ready()
    {
        _bikebody = GetNode<BikeBody>("BikeBody");
        _droneRegistry = GetNode<DroneRegistry>("/root/DroneRegistry");
        _camera = GetNode<Camera3D>("Camera3D");
        _maxProgress = GetParent<Path3D>().Curve.GetBakedLength();
        _timerThreshold = 1.0f / PrSecChecks;
    }

    public override void _PhysicsProcess(double delta)
    {
        float fDelta = (float)delta;
        _timer += fDelta;
        _totalTime += fDelta;

        if (_timer >= _timerThreshold)
        {
            _timer -= _timerThreshold;
            Controller(fDelta);
        }

        Progress += Speed * fDelta;

        if (Progress >= _maxProgress)
        {
            if (!IsRl)
                GD.Print("Bike: ", Name, " Finish time: ", _totalTime);
            SafeQueueFree();
        }
    }

    private void Controller(float delta)
    {
        Control1(delta);
    }

    private void Control1(float delta)
    {
        float elevation = -1f * _bikebody.GlobalRotation.X;
        float wantedPower = _sustainableWatt;

        PelotonResult result = FindNearbyBikesInFront();

        if (result.NBikes == 0 || (result.DistTo1st.HasValue && result.DistTo1st.Value > 6f) || ProgressRatio >= 0.985f)
            _inPeloton = false;
        else
            _inPeloton = true;

        BehaviorChange(delta, elevation);

        if (_behavior == BikeState.Cruise)
            wantedPower = Cruise(elevation, result);
        else if (_behavior == BikeState.Attack)
            wantedPower = Attack();

        float actualPower = wantedPower;
        if (wantedPower > _sustainableWatt)
            actualPower = Mathf.Min(MaxPossiblePower(), wantedPower);

        _acceleration = AccelerationBasedOnSpeed(Speed, elevation, actualPower, _inPeloton);
        FatigueChanges(actualPower);
        Speed = Mathf.Max(0.5f, Speed + _acceleration * delta);
    }

    private float Cruise(float elevation, PelotonResult rayHits)
    {
        if (!_inPeloton)
            return Solo();

        float distToCenter = rayHits.AvgDist;
        float? distTo1 = rayHits.DistTo1st;
        float? distTo3 = rayHits.DistTo3rd;

        float sepMod = 0f;
        if (distTo3.HasValue)
            sepMod = 1f / Mathf.Max(0.5f, distTo3.Value);
        else if (distTo1.HasValue)
            sepMod = 1f / Mathf.Max(0.5f, distTo1.Value);

        float additionalForceAmplification = distToCenter * _cohesionC - sepMod * _separationC;
        return _sustainableWatt * 0.7f * additionalForceAmplification;
    }

    private float Attack() => _initialBreakoutWatt;

    private float Solo() => _sustainableWatt;

    private void BehaviorChange(float delta, float elevation)
    {
        if (_sustainableWatt > 390f && ProgressRatio > 0.985f && _behavior != BikeState.Attack)
        {
            _behavior = BikeState.Attack;
            return;
        }

        if (_behavior == BikeState.Attack && ProgressRatio <= 0.985f)
        {
            if (elevation < 0f || _rng.RandiRange(0, 1000) < _speedDownProbability * delta)
            {
                _behavior = BikeState.Cruise;
                return;
            }
        }

        if (_behavior == BikeState.Cruise && elevation > 0.017f)
        {
            float threshold = (_speedUpProbability * (elevation / 0.034f) * delta) / Mathf.Max(1f - ProgressRatio, 0.15f);
            if (_rng.RandiRange(0, 10000) < threshold)
                _behavior = BikeState.Attack;
        }
    }

    private void FatigueChanges(float currentWatt)
    {
        if (currentWatt == _sustainableWatt)
            return;
        _fatigue = Mathf.Max(0f, _fatigue + currentWatt - _sustainableWatt);
    }

    public float CalcWattCurrentState(float speedMs, float elevation, float accelerationMss, bool inPeloton = false)
    {
        float dragModifier = inPeloton ? 0.7f : 1f;
        return 82.9897f * speedMs * (accelerationMss + 0.0024f * dragModifier * speedMs * speedMs + 0.0390f + 9.81f * Mathf.Sin(elevation));
    }

    public float AccelerationBasedOnSpeed(float speedMs, float elevation, float power, bool inPeloton = false)
    {
        float dragModifier = inPeloton ? 0.7f : 1f;
        return ((power * 0.97f / 80.5f) / speedMs) - 0.0024f * dragModifier * speedMs * speedMs - 0.0390f - 9.81f * Mathf.Sin(elevation);
    }

    private float MaxPossiblePower()
    {
        if (_fatigue < _fatigueThreashold)
            return _sustainableWatt + WattLimitedByStamina();
        return WattLimitedByFatigue();
    }

    private float WattLimitedByFatigue() =>
        (_sustainableWatt + WattLimitedByStamina()) * Mathf.Exp(-_aFatigueResistence * (_fatigue - _fatigueThreashold));

    private float WattLimitedByStamina()
    {
        float breakAwayBonus = _initialBreakoutWatt - _sustainableWatt;
        return breakAwayBonus * Mathf.Exp(-_bStaminaDegresse * breakAwayBonus * _totalTime);
    }

    public void SetWatts(float sustainableWatt = 355f, float initialBreakoutWatt = 531f)
    {
        _sustainableWatt = sustainableWatt;
        _initialBreakoutWatt = initialBreakoutWatt;
    }

    public static Dictionary GetRandomizeForRl()
    {
        var rng = new RandomNumberGenerator();
        float speed = rng.RandfRange(6.0f, 18.0f);
        int speedUpProbability = rng.RandiRange(4, 16);
        float cohesionC = rng.RandfRange(0.1f, 1.0f);
        float separationC = rng.RandfRange(0.01f, 1f);
        return new Dictionary
        {
            ["speed"] = speed,
            ["speedUpProbability"] = speedUpProbability,
            ["cohesion_c"] = cohesionC,
            ["separation_c"] = separationC,
        };
    }

    public void SetRandomizeForRl(Dictionary dict)
    {
        Speed = (float)dict["speed"];
        _speedUpProbability = (int)dict["speedUpProbability"];
        _cohesionC = (float)dict["cohesion_c"];
        _separationC = (float)dict["separation_c"];
    }

    public Camera3D GetCameraNode() => _camera;

    private PelotonResult FindNearbyBikesInFront()
    {
        const float maxDist = 30f;
        var myPos = GlobalPosition;
        var forward = -GlobalTransform.Basis.Z;
        forward.Y = 0f;
        forward = forward.Normalized();

        _aheadDistances.Clear();
        foreach (var other in _droneRegistry.BikeList)
        {
            if (other == _bikebody) continue;
            var toOther = other.GlobalPosition - myPos;
            if (toOther.Dot(forward) <= 0f) continue;
            float dist = toOther.Length();
            if (dist <= maxDist)
                _aheadDistances.Add(dist);
        }

        _aheadDistances.Sort();

        int n = _aheadDistances.Count;
        float sum = 0f;
        for (int i = 0; i < n; i++) sum += _aheadDistances[i];

        return new PelotonResult(
            n,
            n > 0 ? sum / n : 0f,
            n >= 1 ? _aheadDistances[0] : null,
            n >= 3 ? _aheadDistances[2] : null
        );
    }

    public void SafeQueueFree()
    {
        EmitSignal(SignalName.FreeingBike, this);
        _bikebody.CollisionLayer = 0;
        QueueFree();
    }
}

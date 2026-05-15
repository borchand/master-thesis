using Godot;
using Godot.Collections;

[GlobalClass]
public partial class Bike : PathFollow3D
{
    [Signal]
    public delegate void FreeingBikeEventHandler(Bike bike);

    private BikeRayCast _raycast;
    private BikeBody _bikebody;

    private RandomNumberGenerator _rng = new RandomNumberGenerator();
    private float _maxProgress;

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

    // sustainable_force = 25 (not used)
    private float? _sustainableWatt = null;
    private float? _initialBreakoutWatt = null;
    private float _aFatigueResistence = 0.00003f;
    private float _fatigueThreashold = 52800.0f;
    private float _bStaminaDegresse = 0.0000002f;
    private float _fatigue = 0f;
    private bool _inPeloton = false;
    private string _behavior = "cruise";

    private float _cohesionC = 0.8f;
    private float _separationC = 0.05f;

    public override void _Ready()
    {
        _raycast = GetNode<BikeRayCast>("RayCast3D");
        _bikebody = GetNode<BikeBody>("BikeBody");
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
        float? wantedPower = _sustainableWatt;

        BikeRayCast.RaycastResult result = _raycast.RunRaycast();

        if (result.NBikes == 0 || (result.DistTo1st.HasValue && result.DistTo1st.Value > 6f) || ProgressRatio >= 0.985f)
            _inPeloton = false;
        else
            _inPeloton = true;

        BehaviorChange(delta, elevation);

        if (_behavior == "cruise")
            wantedPower = Cruise(elevation, result);
        else if (_behavior == "attack")
            wantedPower = Attack();

        float actualPower = wantedPower ?? 0f;
        if (wantedPower > _sustainableWatt)
            actualPower = Mathf.Min(MaxPossiblePower(), wantedPower.Value);

        _acceleration = AccelerationBasedOnSpeed(Speed, elevation, actualPower, _inPeloton);
        FatigueChanges(actualPower);
        Speed = Mathf.Max(0.5f, Speed + _acceleration * delta);
    }

    private float Cruise(float elevation, BikeRayCast.RaycastResult rayHits)
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
        return (_sustainableWatt ?? 0f) * 0.7f * additionalForceAmplification;
    }

    private float Attack()
    {
        return _initialBreakoutWatt ?? 0f;
    }

    private float Solo()
    {
        return _sustainableWatt ?? 0f;
    }

    private void BehaviorChange(float delta, float elevation)
    {
        if (_sustainableWatt > 390f && ProgressRatio > 0.985f && _behavior != "attack")
        {
            _behavior = "attack";
            return;
        }

        if (_behavior == "attack" && ProgressRatio <= 0.985f)
        {
            if (elevation < 0f || _rng.RandiRange(0, 1000) < _speedDownProbability * delta)
            {
                _behavior = "cruise";
                return;
            }
        }

        if (_behavior == "cruise" && elevation > 0.017f)
        {
            float threshold = (_speedUpProbability * (elevation / 0.034f) * delta) / Mathf.Max(1f - ProgressRatio, 0.15f);
            if (_rng.RandiRange(0, 10000) < threshold)
                _behavior = "attack";
        }
    }

    private void FatigueChanges(float currentWatt)
    {
        if (currentWatt == _sustainableWatt)
            return;
        _fatigue = Mathf.Max(0f, _fatigue + currentWatt - (_sustainableWatt ?? 0f));
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
            return (_sustainableWatt ?? 0f) + WattLimitedByStamina();
        else
            return WattLimitedByFatigue();
    }

    private float WattLimitedByFatigue()
    {
        return ((_sustainableWatt ?? 0f) + WattLimitedByStamina()) * Mathf.Exp(-_aFatigueResistence * (_fatigue - _fatigueThreashold));
    }

    private float WattLimitedByStamina()
    {
        float breakAwayBonus = (_initialBreakoutWatt ?? 0f) - (_sustainableWatt ?? 0f);
        return breakAwayBonus * Mathf.Exp(-1f * _bStaminaDegresse * breakAwayBonus * _totalTime);
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

    public Camera3D GetCameraNode() => GetNode<Camera3D>("Camera3D");

    public void SafeQueueFree()
    {
        EmitSignal(SignalName.FreeingBike, this);
        _bikebody.CollisionLayer = 0;
        QueueFree();
    }
}

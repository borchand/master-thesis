using Godot;
using Godot.Collections;

[GlobalClass]
public partial class BikeRayCast : RayCast3D
{
    public record struct RaycastResult(int NBikes, float AvgDist, float? DistTo1st, float? DistTo3rd);

    private float _timer = 0f;
    private float _timerThreshold = 0f;
    private int _rayCastLength = 30;

    public override void _Ready()
    {
        _timerThreshold = 1.0f / GetParent<Bike>().PrSecChecks;
    }

    public override void _PhysicsProcess(double delta)
    {
        _timer += (float)delta;
        if (_timer >= _timerThreshold)
        {
            _timer -= _timerThreshold;
            RunRaycast();
        }
    }

    public RaycastResult RunRaycast()
    {
        var parent = GetParent<Bike>();
        var origin = parent.Position + parent.GlobalTransform.Basis.Z * 1.7f;
        var spaceState = GetWorld3D().DirectSpaceState;
        var query = PhysicsRayQueryParameters3D.Create(origin, origin - parent.GlobalTransform.Basis.Z * _rayCastLength);
        var results = MultiRaycast(spaceState, query);

        float sum = 0f;
        int nBikes = 0;
        float? distToBike3rd = null;
        float? distToBike1st = null;

        foreach (var hit in results)
        {
            if (hit["collider"].As<GodotObject>() is BikeBody)
            {
                nBikes++;
                float dist = origin.DistanceTo((Vector3)hit["position"]);
                sum += dist;
                if (nBikes == 1)
                    distToBike1st = dist;
                if (nBikes == 3)
                    distToBike3rd = dist;
            }
            else
            {
                var colliderNode = hit["collider"].As<Node>();
                GD.Print("collided with ", colliderNode?.GetParent()?.Name);
            }
        }

        float avgDist = sum / Mathf.Max(1, nBikes);
        return new RaycastResult(nBikes, avgDist, distToBike1st, distToBike3rd);
    }

    private System.Collections.Generic.List<Dictionary> MultiRaycast(
        PhysicsDirectSpaceState3D spaceState,
        PhysicsRayQueryParameters3D query,
        int maxIterations = 8)
    {
        var hits = new System.Collections.Generic.List<Dictionary>();
        var exclusions = new Array<Rid>();
        PhysicsRayQueryParameters3D nextQuery = query;
        int counter = 0;

        while (nextQuery != null && counter <= maxIterations)
        {
            var result = spaceState.IntersectRay(nextQuery);
            if (result.Count > 0)
            {
                hits.Add(result.Duplicate());
                exclusions.Add(result["rid"].As<Rid>());
                nextQuery = PhysicsRayQueryParameters3D.Create(query.From, query.To, query.CollisionMask, exclusions);
            }
            else
            {
                nextQuery = null;
            }
            counter++;
        }

        return hits;
    }
}

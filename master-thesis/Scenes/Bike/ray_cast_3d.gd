extends RayCast3D
var timer := 0.0
var timer_threashold = 0
var RayCastLength = 20

func _ready() -> void:
	timer_threashold= 1.0/get_parent().pr_sec_checks


func _physics_process(delta): 
	timer += delta
	if timer >= timer_threashold:
		timer = timer-timer_threashold
		run_raycast()


func run_raycast():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(get_parent().position, get_parent().position-get_parent().global_transform.basis.z*RayCastLength) 
	var results = multi_raycast(space_state, query)
	var sum = 0
	var n_bikes = 0 
	var dist_to_bike_2th = null
	var dist_to_bike_1st = null
	var origin = get_parent().position
	for y in results: 
		if y["collider"] is Bike_body:
			n_bikes += 1
			sum += origin.distance_to(y["position"])
			if n_bikes == 1: 
				dist_to_bike_1st = origin.distance_to(y["position"])
			if n_bikes == 2: 
				dist_to_bike_2th = origin.distance_to(y["position"])
		else:
			print("collided with ", y["collider"].get_parent().name)
		
	return [n_bikes, (sum/max(1, n_bikes)), dist_to_bike_1st ,dist_to_bike_2th,]

func multi_raycast(space_state: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, max_iterations: int = 6) -> Array[Dictionary]:
	var next_query = query
	var hits: Array[Dictionary] = []
	var exclusions: Array[RID] = []
	var counter := 0
	while (next_query != null) and (not counter > max_iterations):
		var result = space_state.intersect_ray(next_query)
		if !result.is_empty():
			hits.append(result.duplicate())
			exclusions.append(result.rid)
		next_query = null if result.is_empty() else PhysicsRayQueryParameters3D.create(query.from, query.to, query.collision_mask, exclusions)
		counter += 1
	return hits

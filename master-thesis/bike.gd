extends Node3D

class_name Bike
signal freeing_bike

var pathFollow: PathFollow3D
var rng = RandomNumberGenerator.new()
var max_progress: float

var Maxspeed = 7.0
var Minspeed = 2.5
var speed = 4.0
var acceleration = 0.0
var stamina = 100.0
var staminaSpeedupThreashold = 70
var staminaSlowdownThreashold = 40
var staminaRegen: float #should be something between 4


func _ready():
	pathFollow = $Path3D/PathFollow3D
	max_progress = pathFollow.get_parent().curve.get_baked_length()
	
func _process(delta):
	print("speed: ", speed, " acc: ", acceleration, " stamina:" ,stamina, " regen: ", staminaRegen)
	if staminaRegen == null:
		staminaRegen = rng.randf_range(3.0, 4.0)
	#Slow down if stamina low
	if stamina<staminaSlowdownThreashold:
		acceleration -= 0.0003*(staminaSlowdownThreashold-stamina)
	elif stamina>staminaSpeedupThreashold and (rng.randi_range(0,100)+(staminaSpeedupThreashold-stamina)*0.5) < 2 :
		acceleration += 0.0002
	#Change in speed and stamina
	speed = max(Minspeed, min(Maxspeed, speed+acceleration))
	stamina = min(100.0, stamina+staminaRegen*0.25-speed*0.5)
	if speed==Minspeed: #on min speed stamina regenerate is double
		acceleration = max(0,acceleration)
		stamina += staminaRegen*0.5 
		
	# move bike forward
	pathFollow.progress += speed * delta
	#Termination Tjek
	if pathFollow.progress >= max_progress:
		# remove bike when it reaches the end of the path
		safe_queue_free()
	
func setRegen(regen: float) -> void:
	staminaRegen = regen
	
func get_camera_node() -> Camera3D:
	return $Path3D/PathFollow3D/Camera3D
	
func safe_queue_free() -> void:
	freeing_bike.emit(self)
	queue_free()

#Neigbor bike accelerating ahead
func _on_proximity_are_bike_body_exited(body: Node3D) -> void:
	if body.name == "BikeHitBox" and stamina >= staminaSlowdownThreashold:
		var pObject = body
		while pObject.get_parent() == null:
			pObject = pObject.get_parent()
		var bike = pObject
		if bike.name == "Bike": 
			acceleration = max(acceleration, bike.acceleration)

extends Node3D
class_name AIController3D

enum ControlModes { INHERIT_FROM_SYNC, HUMAN, TRAINING, ONNX_INFERENCE, RECORD_EXPERT_DEMOS }
@export var control_mode: ControlModes = ControlModes.INHERIT_FROM_SYNC
@export var onnx_model_path := ""

@export_group("Record expert demos mode options")
## Path where the demos will be saved. The file can later be used for imitation learning.
@export var expert_demo_save_path: String
## The action that erases the last recorded episode from the currently recorded data.
@export var remove_last_episode_key: InputEvent
## Action will be repeated for n frames. Will introduce control lag if larger than 1.
## Can be used to ensure that action_repeat on inference and training matches
## the recorded demonstrations.
@export var action_repeat: int = 1

@export_group("Multi-policy mode options")
## Allows you to set certain agents to use different policies.
## Changing has no effect with default SB3 training. Works with Rllib example.
## Tutorial: https://github.com/edbeeching/godot_rl_agents/blob/main/docs/TRAINING_MULTIPLE_POLICIES.md
@export var policy_name: String = "shared_policy"

var onnx_model: ONNXModel

var heuristic := "human"
var done := false
var reward := 0.0
var n_steps := 0
var needs_reset := false
var episode := 0
var accumulated_reward := 0.0

var _player: Node3D


func _ready():
	add_to_group("AGENT")


func init(player: Node3D):
	_player = player

	# create file for writing data
	var file = FileAccess.open("res://drone_data.csv", FileAccess.WRITE)
	file.store_line("episode, steps, accumulated_reward")
	file.close()


#-- Methods that need implementing using the "extend script" option in Godot --#
func get_obs() -> Dictionary:
	assert(false, "the get_obs method is not implemented when extending from ai_controller")
	return {"obs": []}


func get_reward() -> float:
	assert(false, "the get_reward method is not implemented when extending from ai_controller")
	return 0.0


func get_action_space() -> Dictionary:
	assert(
		false,
		"the get_action_space method is not implemented when extending from ai_controller"
	)
	return {
		"example_actions_continous": {"size": 2, "action_type": "continuous"},
		"example_actions_discrete": {"size": 2, "action_type": "discrete"},
	}


func set_action(action) -> void:
	assert(false, "the set_action method is not implemented when extending from ai_controller")


#-----------------------------------------------------------------------------#


#-- Methods that sometimes need implementing using the "extend script" option in Godot --#
# Only needed if you are recording expert demos with this AIController
func get_action() -> Array:
	assert(false, "the get_action method is not implemented in extended AIController but demo_recorder is used")
	return []

# -----------------------------------------------------------------------------#

func _physics_process(delta):
	n_steps += 1
	reward = _player.get_reward()

	accumulated_reward += reward


func get_obs_space():
	# may need overriding if the obs space is complex
	var obs = get_obs()
	return {
		"obs": {"size": [len(obs["obs"])], "space": "box"},
	}


func reset():
	if not episode == 0:
		# create file for writing data
		var per_episode_file = FileAccess.open("res://drone_data_per_episode.csv", FileAccess.WRITE)
		per_episode_file.store_line("episode, step, reward, direction_x, direction_y, direction_z, central_force, torque")
		per_episode_file.close()

		# add data to file
		var file = FileAccess.open("res://drone_data.csv", FileAccess.READ_WRITE)
		file.seek_end()
		file.store_line(str(episode) + ", " + str(n_steps) + ", " + str(accumulated_reward))
		file.close()

	episode += 1
	accumulated_reward = 0.0
	n_steps = 0

	needs_reset = false
	set_done_false()


func reset_if_done():
	if done:
		reset()


func set_heuristic(h):
	# sets the heuristic from "human" or "model" nothing to change here
	heuristic = h


func get_done():
	return done


func set_done_false():
	done = false


func zero_reward():
	reward = 0.0

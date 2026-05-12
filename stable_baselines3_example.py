import argparse
import os
import pathlib
from typing import Callable

import numpy as np
import gymnasium as gym
import torch
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import BaseCallback, CheckpointCallback
from tqdm import tqdm
from stable_baselines3.common.vec_env import VecEnvWrapper
from stable_baselines3.common.vec_env.vec_monitor import VecMonitor

from godot_rl.core.utils import can_import
from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

# To download the env source and binary:
# 1.  gdrl.env_from_hub -r edbeeching/godot_rl_BallChase
# 2.  chmod +x examples/godot_rl_BallChase/bin/BallChase.x86_64
if can_import("ray"):
    print("WARNING, stable baselines and ray[rllib] are not compatible")

parser = argparse.ArgumentParser(allow_abbrev=False)
parser.add_argument(
    "--env_path",
    default=None,
    type=str,
    help="The Godot binary to use, do not include for in editor training",
)
parser.add_argument(
    "--experiment_dir",
    default="logs/sb3",
    type=str,
    help="The name of the experiment directory, in which the tensorboard logs and checkpoints (if enabled) are "
    "getting stored.",
)
parser.add_argument(
    "--experiment_name",
    default="experiment",
    type=str,
    help="The name of the experiment, which will be displayed in tensorboard and "
    "for checkpoint directory and name (if enabled).",
)
parser.add_argument("--seed", type=int, default=0, help="seed of the experiment")
parser.add_argument(
    "--resume_model_path",
    default=None,
    type=str,
    help="The path to a model file previously saved using --save_model_path or a checkpoint saved using "
    "--save_checkpoints_frequency. Use this to resume training or infer from a saved model.",
)
parser.add_argument(
    "--save_model_path",
    default=None,
    type=str,
    help="The path to use for saving the trained sb3 model after training is complete. Saved model can be used later "
    "to resume training. Extension will be set to .zip",
)
parser.add_argument(
    "--save_checkpoint_frequency",
    default=None,
    type=int,
    help=(
        "If set, will save checkpoints every 'frequency' environment steps. "
        "Requires a unique --experiment_name or --experiment_dir for each run. "
        "Does not need --save_model_path to be set. "
    ),
)
parser.add_argument(
    "--onnx_export_path",
    default=None,
    type=str,
    help="If included, will export onnx file after training to the path specified.",
)
parser.add_argument(
    "--timesteps",
    default=2_000_000,
    type=int,
    help="The number of environment steps to train for, default is 1_000_000. If resuming from a saved model, "
    "it will continue training for this amount of steps from the saved state without counting previously trained "
    "steps",
)
parser.add_argument(
    "--inference",
    default=False,
    action="store_true",
    help="Instead of training, it will run inference on a loaded model for --timesteps steps. "
    "Requires --resume_model_path to be set.",
)
parser.add_argument(
    "--linear_lr_schedule",
    default=False,
    action="store_true",
    help="Use a linear LR schedule for training. If set, learning rate will decrease until it reaches 0 at "
    "--timesteps"
    "value. Note: On resuming training, the schedule will reset. If disabled, constant LR will be used.",
)
parser.add_argument(
    "--viz",
    action="store_true",
    help="If set, the simulation will be displayed in a window during training. Otherwise "
    "training will run without rendering the simulation. This setting does not apply to in-editor training.",
    default=False,
)
parser.add_argument("--speedup", default=1, type=int, help="Whether to speed up the physics in the env")
parser.add_argument(
    "--n_steps",
    default=512,
    type=int,
    help=(
        "Number of environment steps collected per agent per PPO update. "
        "Smaller values mean more frequent (but shorter) gradient updates, "
        "which reduces the Godot freeze between rollouts. Default: 512."
    ),
)
parser.add_argument(
    "--n_parallel",
    default=1,
    type=int,
    help="How many instances of the environment executable to " "launch - requires --env_path to be set if > 1.",
)
parser.add_argument(
    "--device",
    default="auto",
    type=str,
    help="Device for neural network training: auto (default), cpu, cuda, or mps (Apple Silicon).",
)
args, extras = parser.parse_known_args()


def resolve_device(requested: str) -> str:
    if requested != "auto":
        return requested
    if torch.cuda.is_available():
        return "cuda"
    if torch.backends.mps.is_available():
        return "mps"
    return "cpu"


device = resolve_device(args.device)
print(f"Training device: {device}")


def handle_onnx_export():
    # Enforce the extension of onnx and zip when saving model to avoid potential conflicts in case of same name
    # and extension used for both
    if args.onnx_export_path is not None:
        path_onnx = pathlib.Path(args.onnx_export_path).with_suffix(".onnx")
        print("Exporting onnx to: " + os.path.abspath(path_onnx))
        export_model_as_onnx(model, str(path_onnx))


def handle_model_save():
    if args.save_model_path is not None:
        zip_save_path = pathlib.Path(args.save_model_path).with_suffix(".zip")
        print("Saving model to: " + os.path.abspath(zip_save_path))
        model.save(zip_save_path)


def close_env():
    try:
        print("closing env")
        env.close()
    except Exception as e:
        print("Exception while closing env: ", e)


def cleanup():
    handle_onnx_export()
    handle_model_save()
    close_env()


class TqdmCallback(BaseCallback):
    def __init__(self, total_timesteps: int):
        super().__init__()
        self._bar = tqdm(total=total_timesteps, unit="step", dynamic_ncols=True)

    def _on_step(self) -> bool:
        self._bar.update(self.training_env.num_envs)
        return True

    def _on_training_end(self) -> None:
        self._bar.close()


path_checkpoint = os.path.join(args.experiment_dir, args.experiment_name + "_checkpoints")
abs_path_checkpoint = os.path.abspath(path_checkpoint)

# Prevent overwriting existing checkpoints when starting a new experiment if checkpoint saving is enabled
if args.save_checkpoint_frequency is not None and os.path.isdir(path_checkpoint):
    raise RuntimeError(
        abs_path_checkpoint + " folder already exists. "
        "Use a different --experiment_dir, or --experiment_name,"
        "or if previous checkpoints are not needed anymore, "
        "remove the folder containing the checkpoints. "
    )

if args.inference and args.resume_model_path is None:
    raise parser.error("Using --inference requires --resume_model_path to be set.")

if args.env_path is None and args.viz:
    print("Info: Using --viz without --env_path set has no effect, in-editor training will always render.")

class CastFloat32(VecEnvWrapper):
    """Re-declare box observation spaces as float32 and cast observations.
    Required for MPS (Apple Metal) which does not support float64 tensors."""

    def __init__(self, venv):
        obs_space = venv.observation_space
        if isinstance(obs_space, gym.spaces.Dict):
            new_spaces = {
                k: gym.spaces.Box(low=v.low.astype(np.float32), high=v.high.astype(np.float32), dtype=np.float32)
                if isinstance(v, gym.spaces.Box) else v
                for k, v in obs_space.spaces.items()
            }
            new_obs_space = gym.spaces.Dict(new_spaces)
        else:
            new_obs_space = obs_space
        super().__init__(venv, observation_space=new_obs_space)

    def reset(self):
        return self._cast(self.venv.reset())

    def step_wait(self):
        obs, reward, done, info = self.venv.step_wait()
        return self._cast(obs), reward, done, info

    def _cast(self, obs):
        if isinstance(obs, dict):
            return {k: v.astype(np.float32) for k, v in obs.items()}
        return obs.astype(np.float32)


env = StableBaselinesGodotEnv(
    env_path=args.env_path, show_window=args.viz, seed=args.seed, n_parallel=args.n_parallel, speedup=args.speedup
)
if device != "cpu":
    env = CastFloat32(env)
env = VecMonitor(env)


# LR schedule code snippet from:
# https://stable-baselines3.readthedocs.io/en/master/guide/examples.html#learning-rate-schedule
def linear_schedule(initial_value: float) -> Callable[[float], float]:
    """
    Linear learning rate schedule.

    :param initial_value: Initial learning rate.
    :return: schedule that computes
      current learning rate depending on remaining progress
    """

    def func(progress_remaining: float) -> float:
        """
        Progress will decrease from 1 (beginning) to 0.

        :param progress_remaining:
        :return: current learning rate
        """
        return progress_remaining * initial_value

    return func


if args.resume_model_path is None:
    learning_rate = 0.0003 if not args.linear_lr_schedule else linear_schedule(0.0003)
    model: PPO = PPO(
        "MultiInputPolicy",
        env,
        ent_coef=0.0001,
        verbose=0,
        tensorboard_log=args.experiment_dir,
        learning_rate=learning_rate,
        device=device,
        n_steps=args.n_steps,
    )
else:
    path_zip = pathlib.Path(args.resume_model_path)
    print("Loading model: " + os.path.abspath(path_zip))
    model = PPO.load(path_zip, env=env, tensorboard_log=args.experiment_dir, device=device, n_steps=args.n_steps, verbose=0)

if args.inference:
    obs = env.reset()
    for i in range(args.timesteps):
        action, _state = model.predict(obs, deterministic=True)
        obs, reward, done, info = env.step(action)
else:
    callbacks = [TqdmCallback(args.timesteps)]
    if args.save_checkpoint_frequency:
        print("Checkpoint saving enabled. Checkpoints will be saved to: " + abs_path_checkpoint)
        callbacks.append(CheckpointCallback(
            save_freq=(args.save_checkpoint_frequency // env.num_envs),
            save_path=path_checkpoint,
            name_prefix=args.experiment_name,
        ))
    learn_arguments = dict(total_timesteps=args.timesteps, tb_log_name=args.experiment_name, callback=callbacks)
    try:
        model.learn(**learn_arguments)
    except (KeyboardInterrupt, ConnectionError, ConnectionResetError):
        print(
            """Training interrupted by user or a ConnectionError. Will save if --save_model_path was
            used and/or export if --onnx_export_path was used."""
        )
    finally:
        cleanup()

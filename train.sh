#!/bin/bash

function kill_server() {
    lsof -i :8000 | awk 'NR!=1 {print $2}' | xargs kill -9
}

function cleanup() {
    echo "Cleaning up before exiting..."
    echo "Closing server on port 8000..."
    kill_server
    echo "Cleanup complete. Exiting."
}

SAVE_MODEL_PATH=model.zip
EXPERIMENT_NAME=exp1

for arg in "$@"; do
    if [[ $arg == --save_model_path=* ]]; then
        SAVE_MODEL_PATH="${arg#*=}"
    elif [[ $arg == --experiment_name=* ]]; then
        EXPERIMENT_NAME="${arg#*=}"
    fi
done


if [ -f "$SAVE_MODEL_PATH" ]; then
    echo "Model file $SAVE_MODEL_PATH already exists. Do you want to overwrite it? (y/n)"
    read -r answer
    if [ "$answer" != "y" ]; then
        echo "Exiting without overwriting the model file."
        exit 1
    fi
fi

LOG_DIR="logs/sb3/${EXPERIMENT_NAME}"
CHECKPOINT_DIR="logs/sb3/${EXPERIMENT_NAME}_checkpoints"
if [ -d "$CHECKPOINT_DIR" ]; then
    echo "Checkpoint directory $CHECKPOINT_DIR already exists. Do you want to overwrite it? (y/n)"
    read -r answer
    if [ "$answer" = "y" ]; then
        rm -rf "$LOG_DIR"
        rm -rf "$CHECKPOINT_DIR"
    else
        echo "Exiting without overwriting the checkpoint directory."
        exit 1
    fi
fi

trap cleanup INT

kill_server

# start python server
python3.12 -m http.server 8000 &

# remove log file

python3.12 stable_baselines3_example.py --save_model_path="$SAVE_MODEL_PATH" --save_checkpoint_frequency=20_000 --experiment_name="$EXPERIMENT_NAME" --timesteps=2_000_000 --speedup=8



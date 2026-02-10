# Master thesis

## Simulator
The simulator is built using the Godot game engine (version 4.6).

## Godot setup
To run the simulator, you need to have Godot installed on your computer. You can download it from the official website: https://godotengine.org/download. Once you have Godot installed, you can open the project by selecting the `master-thesis` folder in Godot.

## Keybindings in simulator
keybinding | action
--- | ---
`W` | Move forward in free camera mode. Zoom in when not in free camera mode
`S` | Move backward in free camera mode. Zoom out when not in free camera mode  
`A` | Move left in free camera mode
`D` | Move right in free camera mode
`Shift`| Move faster
`Ctrl` | Move slower
`Esc` | Exit simulator
`P` | Toggle pause
`F` | Toggle follow bike mode
`G`| Toggle follow drone mode
`N` | Next bike/drone when in follow bike/drone mode
`B` | Previous bike/drone when in follow bike/drone mode
`R`| Toggle free camera mode
`Shift​+​D` | Toggle to move drone around using arrows
`↑ Up`| Move drone forward when drone movement is toggled on
`↓ Down`| Move drone backwards when drone movement is toggled on
`← Left`| Turn drone left when drone movement is toggled on
`→ Right`| Turn drone right when drone movement is toggled on

## Python scripts
We have written some Python scripts to parse data used in the simulator. Below is a brief description of each script.

### Setup
Install the required dependencies using pip:
```bash
pip install -r requirements.txt
```

## Rider information parser
We use data from Pogacars public Strava account to get information about his ride. Specifically, data from the first stage of the 2025 Tour de France is used. The script `return_min_max_average.py` parses this data and extracts information about the rider's min, average, and max speed.

## Stage conveter
The script `converter.py` is used to convert the stage data from the 2025 Tour de France into a format that can be used in the simulator. The script takes the stage data and converts it into a list of coordinates that represent the path of the stage. This allows us to create a realistic path for the rider to follow in the simulator.

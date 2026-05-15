using Godot;
using Godot.Collections;

[GlobalClass]
public partial class CustomLogger : Node
{
	public bool Logging = true;

	private Dictionary<string, string> _currentRunFolders = new();

	private string _bikes = "";
	private string _drones = "";
	private string _track = "";
	private string _size = "";

	public void AddInfo(int bikes, int drones, string track, int size)
	{
		if (Logging)
		{
			_bikes = bikes.ToString();
			_drones = drones.ToString();
			_track = track.Replace("res://stages/", "").Replace("-route.json", "");
			_size = size.ToString();
		}
	}

	private string GetLogsBasePath()
	{
		string projectPath = ProjectSettings.GlobalizePath("res://");
		string parent1 = System.IO.Path.GetDirectoryName(projectPath.TrimEnd('/', '\\'));
		string parent2 = System.IO.Path.GetDirectoryName(parent1);
		return System.IO.Path.Combine(parent2, "logs");
	}

	private string GetNextRunFolder(string vehicleType)
	{
		if (!Logging)
			return "";

		string logsBase = GetLogsBasePath();
		string typeFolder = System.IO.Path.Combine(logsBase, vehicleType);
		DirAccess.MakeDirRecursiveAbsolute(typeFolder);

		int index = 1;
		while (true)
		{
			string candidate = System.IO.Path.Combine(typeFolder, $"run_{index}");
			if (!DirAccess.DirExistsAbsolute(candidate))
			{
				DirAccess.MakeDirRecursiveAbsolute(candidate);
				return candidate;
			}
			index++;
		}
	}

	public void StartNewRun(string vehicleType)
	{
		string runFolder = GetNextRunFolder(vehicleType);
		_currentRunFolders[vehicleType] = runFolder;
	}

	public void StartRunFile(string vehicleId, string vehicleType)
	{
		if (!Logging)
			return;

		if (!_currentRunFolders.ContainsKey(vehicleType))
			StartNewRun(vehicleType);

		string runFolder = _currentRunFolders[vehicleType];
		string filePath = System.IO.Path.Combine(runFolder, $"{vehicleType}_{vehicleId}.csv");

		var file = FileAccess.Open(filePath, FileAccess.ModeFlags.Write);
		file.StoreLine($"Bikes: {_bikes}, Drones: {_drones}, Stage: {_track}, Size: {_size}");

		if (vehicleType == "drone")
			file.StoreLine("Timestep, Pos x, Pos y, Pos z, Collisions, Bikes-ID");
		else
			file.StoreLine("Timestep, Pos x, Pos y, Pos z");

		file.Close();
	}

	public void AppendLine(string vehicleId, string vehicleType, Godot.Collections.Array data)
	{
		if (!Logging)
			return;

		string runFolder = _currentRunFolders[vehicleType];
		string filePath = System.IO.Path.Combine(runFolder, $"{vehicleType}_{vehicleId}.csv");

		var file = FileAccess.Open(filePath, FileAccess.ModeFlags.ReadWrite);
		file.SeekEnd();
		file.StoreLine(string.Join(",", data));
		file.Close();
	}
}

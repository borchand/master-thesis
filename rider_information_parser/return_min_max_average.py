import re

def process_data_to_file(input_filename, output_filename):
    try:
        # 1. Read the raw data
        with open(input_filename, 'r') as file:
            content = file.read()
        
        # 2. Extract numbers using Regex
        numbers_str = re.findall(r"[-+]?\d*\.\d+|\d+", content)
        data = [float(n) for n in numbers_str]

        if not data:
            print("No numbers found in the input file.")
            return

        # 3. Calculations (Assuming m/s to km/h conversion)
        
        highest = max(data)
        average = sum(data) / len(data)
        dataFiltere = [n for n in data if n >= 3]
        lowest = min(dataFiltere)
        
        # Optional: Convert m/s to km/h
        low_kmh = lowest * 3.6
        high_kmh = highest * 3.6
        avg_kmh = average * 3.6

        # 4. Format the results string
        results_text = (
            f"--- Strava Data Analysis ---\n"
            f"Total Data Points: {len(data)}\n\n"
            f"RAW DATA (m/s):\n"
            f"Lowest:  {lowest:.2f}\n"
            f"Highest: {highest:.2f}\n"
            f"Average: {average:.2f}\n\n"
            f"CONVERTED DATA (km/h):\n"
            f"Lowest:  {low_kmh:.2f} km/h\n"
            f"Highest: {high_kmh:.2f} km/h\n"
            f"Average: {avg_kmh:.2f} km/h\n"
        )

        # 5. Write results to a new text file
        with open(output_filename, 'w') as out_file:
            out_file.write(results_text)
            
        print(f"Success! Analysis written to {output_filename}")

    except FileNotFoundError:
        print(f"Error: Could not find '{input_filename}'.")
    except Exception as e:
        print(f"An error occurred: {e}")

# Run the script
if __name__ == "__main__":
    # Ensure your data is saved in '_' first
    process_data_to_file('pogacar_stage1.txt', 'results.txt')
import os
import shutil
import subprocess
import time
import tkinter.messagebox as messagebox

# Set the directory to monitor
dir_path = r"C:\Users\U15405\OneDrive - Kimberly-Clark\Downloads"

# Set the destination directory to move the file
dest_path = r"C:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Files\PowerBI\Tableau Conversion"

# Set the time interval to check for new files (in seconds)
interval = 60 * 60  # 1 hour

while True:
    # Get the list of files in the directory
    files = os.listdir(dir_path)

    # Filter the list to only include ".pbix" files
    pbix_files = [f for f in files if f.endswith(".pbix")]

    # Check if any ".pbix" files were modified within the previous hour
    for pbix_file in pbix_files:
        file_path = os.path.join(dir_path, pbix_file)
        mod_time = os.path.getmtime(file_path)
        current_time = time.time()
        time_diff = current_time - mod_time
        if time_diff < interval:
            # Prompt the user to move the file
            move_file = messagebox.askquestion(
                "Move File",
                f"The file '{pbix_file}' was modified within the previous hour. Do you want to move it?",
            )
            if move_file == "yes":
                # Move the file to the destination directory
                shutil.move(file_path, dest_path)

                # Open the destination directory in Windows Explorer
                subprocess.Popen(
                    f'explorer /select,"{os.path.join(dest_path, pbix_file)}"'
                )

            else:
                # Open the file and the directory in Windows Explorer
                subprocess.Popen(f'explorer /select,"{file_path}"')
                # subprocess.Popen(f'explorer /select,"{dir_path}"')

    # Wait for the specified interval before checking again
    # time.sleep(interval)

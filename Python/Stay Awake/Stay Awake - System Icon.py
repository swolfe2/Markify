import os
import random
import sys
import threading
import time
from datetime import datetime

import pyautogui
import pystray
from PIL import Image

# Constants
TIME_START = "07:00:00"
TIME_END = "18:00:00"
PIXEL_MOVE = 5
MIN_SECONDS = 60
MAX_SECONDS = 240

# Variables
num_moves = 0
stop_flag = False
current_message = ""


# Method to see if current time is between the time start/time end
def is_now_in_time_period(start_time, end_time, now_time, num_moves):
    global stop_flag
    time_string = "time" if num_moves == 1 else "times"
    if not (start_time <= now_time <= end_time):
        # Clear the line and print the new message
        print("\033[2J\033[H", end="")
        print(f"Sold work today! We ran a total of {num_moves} {time_string}.")
        stop_flag = True


# Function to update the tooltip text
def update_tooltip(icon, message):
    global current_message
    current_message = message
    icon.title = message


# Refresh console every second, counting down the number of seconds left until next
def waiting(sleep_seconds, icon):
    sleep_second_counter = 0
    time_string = "time"

    while sleep_second_counter <= sleep_seconds:
        if stop_flag:
            break

        # Calculate remaining seconds
        sleep_seconds_left = sleep_seconds - sleep_second_counter

        # Create strings for messaging
        time_string = "time" if num_moves == 1 else "times"
        second_string = "second" if sleep_seconds_left == 1 else "seconds"
        moved_message = (
            ""
            if num_moves == 0
            else f"Moved {num_moves} {time_string} to keep you safe! \n"
        )

        message = (
            f"{moved_message}"
            f"Next system movement happening in {sleep_seconds_left} {second_string}."
        )

        update_tooltip(icon, message)
        sleep_second_counter += 1
        time.sleep(1)


# Function to run the main script
def run_script(icon):
    global num_moves, PIXEL_MOVE
    while not stop_flag:
        # Check to see if it's during work hours. If it's not, then exit.
        is_now_in_time_period(
            TIME_START, TIME_END, datetime.now().strftime("%H:%M:%S"), num_moves
        )

        if stop_flag:
            break

        # Wait the right number of seconds, displaying a countdown message for every second
        waiting(random.randint(MIN_SECONDS, MAX_SECONDS), icon)

        if stop_flag:
            break

        # Calculate height and width of screen
        w, h = pyautogui.size()

        # Get current position
        x, y = pyautogui.position()

        # Set whether we're going left or right on the screen. Positive = right, negative = left
        if x + PIXEL_MOVE <= 1 or x + PIXEL_MOVE >= w:
            PIXEL_MOVE = -PIXEL_MOVE

        # Turning num lock on/off is the easiest one to do, but any button can be pressed.
        pyautogui.press("numlock")
        pyautogui.press("numlock")
        num_moves += 1

    # Stop the icon
    icon.stop()


# Function to quit the application
def quit_app(icon, item):
    global stop_flag
    stop_flag = True
    icon.stop()


# Get the directory of the currently running script
script_dir = os.path.dirname(os.path.abspath(__file__))

# Construct the path to the icon file
icon_path = os.path.join(script_dir, "icon", "python.ico")

# Create the system tray icon
icon = pystray.Icon("test_icon")
icon.icon = Image.open(icon_path)
icon.title = os.path.basename(__file__)  # Set the initial tooltip to the script name
icon.menu = pystray.Menu(pystray.MenuItem("Quit", quit_app))

# Run the script in a separate thread
thread = threading.Thread(target=run_script, args=(icon,))
thread.start()

# Run the icon
icon.run()

# Ensure the icon stops when the script ends
if stop_flag:
    icon.stop()

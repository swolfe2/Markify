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


def is_now_in_time_period(start_time, end_time, now_time):
    """Check if the current time is within the specified range."""
    return start_time <= now_time <= end_time


def update_tooltip(icon, message):
    """Update the tooltip text."""
    global current_message
    current_message = message
    icon.title = message


def waiting(sleep_seconds, icon):
    """Refresh console every second, counting down the number of seconds left until next."""
    global stop_flag, num_moves
    sleep_second_counter = 0

    while sleep_second_counter <= sleep_seconds:
        if stop_flag:
            break

        sleep_seconds_left = sleep_seconds - sleep_second_counter
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


def run_script(icon):
    """Run the main script."""
    global num_moves, PIXEL_MOVE, stop_flag
    while not stop_flag:
        now_time = datetime.now().strftime("%H:%M:%S")
        if not is_now_in_time_period(TIME_START, TIME_END, now_time):
            print("\033[2J\033[H", end="")
            print(
                f"Sold work today! We ran a total of {num_moves} {'time' if num_moves == 1 else 'times'}."
            )
            stop_flag = True
            break

        waiting(random.randint(MIN_SECONDS, MAX_SECONDS), icon)

        if stop_flag:
            break

        w, h = pyautogui.size()
        x, y = pyautogui.position()

        if x + PIXEL_MOVE <= 1 or x + PIXEL_MOVE >= w:
            PIXEL_MOVE = -PIXEL_MOVE

        pyautogui.press("numlock")
        pyautogui.press("numlock")
        num_moves += 1

    icon.stop()


def quit_app(icon, item):
    """Quit the application."""
    global stop_flag
    stop_flag = True
    icon.stop()


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    icon_path = os.path.join(script_dir, "icon", "python.ico")

    icon = pystray.Icon("test_icon")
    icon.icon = Image.open(icon_path)
    icon.title = os.path.basename(__file__)
    icon.menu = pystray.Menu(pystray.MenuItem("Quit", quit_app))

    thread = threading.Thread(target=run_script, args=(icon,))
    thread.start()

    icon.run()

    if stop_flag:
        icon.stop()


if __name__ == "__main__":
    now_time = datetime.now().strftime("%H:%M:%S")
    if not is_now_in_time_period(TIME_START, TIME_END, now_time):
        print("Current time is outside the specified range. Exiting script.")
        sys.exit()

    main()

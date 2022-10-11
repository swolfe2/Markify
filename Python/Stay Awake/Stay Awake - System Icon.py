import threading
import time
from datetime import datetime
from os import path as path

import PIL.Image
import pyautogui
import pystray


def run_icon():
    # Set main file path for current file
    dir_path = path.dirname(path.realpath(__file__))

    icon_image = "\\Icon\\Python.ico"

    full_path = dir_path + icon_image

    image = PIL.Image.open(full_path)

    # Handle click events to icon
    def on_clicked(icon, item):
        if str(item) == "Quit":
            icon.stop()

    # Create system tray icon
    icon = pystray.Icon(
        "Stay Awake",
        image,
        menu=pystray.Menu(
            pystray.MenuItem("Quit", on_clicked),
        ),
    )

    # Start running in system tray
    icon.run(setup=main_loop())


def main_loop():

    # Set Start Time
    time_start = "07:00:00"

    # Set End Time
    time_end = "18:00:00"

    # Set sleep second integer
    sleep_seconds = 240

    # Set number of pixels to move
    pixel_move = 5

    # Start number of moves counter
    num_moves = 0

    # Refresh console every second, counting down the number of seconds left until next
    def wait_loop(sleep_seconds):
        sleep_second_counter = 0
        while sleep_second_counter <= sleep_seconds:
            sleep_seconds_left = sleep_seconds - sleep_second_counter
            print(
                "Moved "
                + str(num_moves)
                + " times to keep you safe! "
                + "Next system movement happening in "
                + str(sleep_seconds_left)
                + " seconds. "
                + "Press Ctrl+C to stop script. ",
                end="\r",
            )
            sleep_second_counter += 1
            time.sleep(1)

    # Method to see if current time is between the time start/time end
    def check_timeperiod(start_time, end_time, now_time, num_moves):
        if not (now_time >= start_time and now_time <= end_time):
            print(
                "Sold work today! "
                + "\n"
                + "We ran a total of "
                + str(num_moves)
                + " times, which covered you for "
                + str(round(int(num_moves) * int(sleep_seconds) / 60, 2))
                + " minutes.",
                end="\r",
            )
            exit()

    # Loop until CTRL+C is pushed
    try:
        while True:
            # Check to see if it's during work hours. If it's not, then exit.
            check_timeperiod(
                time_start, time_end, datetime.now().strftime("%H:%M:%S"), num_moves
            )

            # Wait the right number of seconds, displaying a countdown message for every second
            wait_loop(sleep_seconds)

            # Turning num lock on/off is the easiest one to do. However, you can really press any button you want.
            pyautogui.keyDown("numlock")
            pyautogui.keyUp("numlock")
            pyautogui.keyDown("numlock")
            pyautogui.keyUp("numlock")
            num_moves += 1

    # Pressing CTRL+C will stop script
    except KeyboardInterrupt:
        pass


def main():
    run_icon()


if __name__ == "__main__":
    main()

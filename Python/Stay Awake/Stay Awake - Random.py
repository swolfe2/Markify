import random
import time
from datetime import datetime

import pyautogui

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


# Refresh console every second, counting down the number of seconds left until next
def waiting(sleep_seconds):
    sleep_second_counter = 0

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
            else f"Moved {num_moves} {time_string} to keep you safe! "
        )

        message = (
            f"{moved_message}"
            f"Next system movement happening in {sleep_seconds_left} {second_string}."
        )

        print(f"\r{message}", end="")

        sleep_second_counter += 1
        time.sleep(1)


# Loop between time windows
while not stop_flag:
    # Check to see if it's during work hours. If it's not, then exit.
    is_now_in_time_period(
        TIME_START, TIME_END, datetime.now().strftime("%H:%M:%S"), num_moves
    )

    if stop_flag:
        break

    # Wait the right number of seconds, displaying a countdown message for every second
    waiting(random.randint(MIN_SECONDS, MAX_SECONDS))

    # Calculate height and width of screen
    w, h = list(pyautogui.size())[0], list(pyautogui.size())[1]

    # Get current position
    x, y = list(pyautogui.position())[0], list(pyautogui.position())[1]

    # Set whether we're going left or right on the screen. Positive = right, negative = left
    if x + PIXEL_MOVE <= 1 or x + PIXEL_MOVE >= w:
        PIXEL_MOVE = PIXEL_MOVE * -1

    # If you prefere a mouse jitter, uncomment out below. Otherwise, just stick turning the key on/off really quick.
    # Also, if you would rather just have the mouse ping pong across the screen, keep the top line of the below
    """
    pyautogui.moveTo(x + PIXEL_MOVE, y)
    pyautogui.moveTo(x - PIXEL_MOVE, y)
    pyautogui.moveTo(x, y)
    """

    # Turning num lock on/off is the easiest one to do. However, you can really press any button you want.
    pyautogui.keyDown("numlock")
    pyautogui.keyUp("numlock")
    pyautogui.keyDown("numlock")
    pyautogui.keyUp("numlock")
    num_moves += 1

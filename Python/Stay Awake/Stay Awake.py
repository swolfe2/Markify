import pyautogui
import time
from datetime import datetime

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

# Method to see if current time is between the time start/time end
def isNowInTimePeriod(start_time, end_time, now_time, num_moves):
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


# Refresh console every second, counting down the number of seconds left until next
def waiting(sleep_seconds):
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


# Loop until CTRL+C is pushed
try:
    while True:
        # Check to see if it's during work hours. If it's not, then exit.
        isNowInTimePeriod(
            time_start, time_end, datetime.now().strftime("%H:%M:%S"), num_moves
        )

        # Wait the right number of seconds, displaying a countdown message for every second
        waiting(sleep_seconds)

        # Calculate height and width of screen
        w, h = list(pyautogui.size())[0], list(pyautogui.size())[1]

        # Get current position
        x, y = list(pyautogui.position())[0], list(pyautogui.position())[1]

        # Set whether we're going left or right on the screen. Positive = right, negative = left
        if x + pixel_move <= 1 or x + pixel_move >= w:
            pixel_move = pixel_move * -1

        # If you prefere a mouse jitter, uncomment out below. Otherwise, just stick turning the key on/off really quick.
        # Also, if you would rather just have the mouse ping pong across the screen, keep the top line of the below
        """
        pyautogui.moveTo(x + pixel_move, y)
        pyautogui.moveTo(x - pixel_move, y)
        pyautogui.moveTo(x, y)
        """

        # Turning num lock on/off is the easiest one to do. However, you can really press any button you want.
        pyautogui.keyDown("numlock")
        pyautogui.keyUp("numlock")
        pyautogui.keyDown("numlock")
        pyautogui.keyUp("numlock")
        num_moves += 1


# Pressing CTRL+C will stop script
except KeyboardInterrupt:
    pass

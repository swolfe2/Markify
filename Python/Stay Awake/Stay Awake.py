import pyautogui
import time
from datetime import datetime

# calculate height and width of screen
w, h = list(pyautogui.size())[0], list(pyautogui.size())[1]

# Set Start Time
timeStart = "08:00:00"

# Set End Time
timeEnd = "18:00:00"

# Set sleep second integer
sleep_seconds = 240

# Set number of pixels to move
pixel_move = 25

# Start number of moves counter
num_moves = 0

# Method to see if current time is between the time start/time end
def isNowInTimePeriod(startTime, endTime, nowTime, num_moves):
    if not (nowTime >= startTime and nowTime <= endTime):
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
            timeStart, timeEnd, datetime.now().strftime("%H:%M:%S"), num_moves
        )

        # Wait the right number of seconds, displaying a countdown message for every second
        waiting(sleep_seconds)

        # Get current position
        x, y = list(pyautogui.position())[0], list(pyautogui.position())[1]

        # Set whether we're going left or right on the screen. Positive = right, negative = left
        if x == 1 or x == w - 1:
            pixel_move = pixel_move * -1

        # If you want to enable mouse moves, uncomment out above. Otherwise, just stick turning numlock on/off really quick.
        # pyautogui.moveTo(x + pixel_move, y)
        # pyautogui.moveTo(x - pixel_move, y)
        pyautogui.keyDown("numlock")
        pyautogui.keyUp("numlock")
        pyautogui.keyDown("numlock")
        pyautogui.keyUp("numlock")
        num_moves += 1


# Pressing CTRL+C will stop script
except KeyboardInterrupt:
    pass

import pyautogui
import time
from datetime import datetime

# calculate height and width of screen
w, h = list(pyautogui.size())[0], list(pyautogui.size())[1]

# Set Start Time
timeStart = "08:00:00"

# Set End Time
timeEnd = "13:46:00"

# Set sleep second integer
sleep_seconds = 20

# Start number of moves counter
num_moves = 0

# Method to see if current time is between the time start/time end
def isNowInTimePeriod(startTime, endTime, nowTime, num_moves):
    if not (nowTime >= startTime and nowTime <= endTime):
        print(
            "Time to go! We ran a total of "
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
        isNowInTimePeriod(
            timeStart, timeEnd, datetime.now().strftime("%H:%M:%S"), num_moves
        )

        # Get current position
        x, y = list(pyautogui.position())[0], list(pyautogui.position())[1]
        # Move mouse 1 pixel to right every X number of seconds
        pyautogui.moveTo(x + 1, y)
        num_moves += 1
        print(
            "Moved "
            + str(num_moves)
            + " times to keep you safe! Press Ctrl+C to stop script. ",
            end="\r",
        )

        time.sleep(sleep_seconds)
# Pressing CTRL+C will stop script
except KeyboardInterrupt:
    pass

import pyautogui
import time

# calculate height and width of screen
w, h = list(pyautogui.size())[0], list(pyautogui.size())[1]

# Loop until CTRL+C is pushed
try:
    while True:
        # Get current position
        x, y = list(pyautogui.position())[0], list(pyautogui.position())[1]
        # Move mouse 1 pixel to right every X number of seconds
        pyautogui.moveTo(x + 1, y)
        time.sleep(10)
# Pressing CTRL+C will stop script
except KeyboardInterrupt:
    pass

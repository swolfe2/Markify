from os import path as path

import PIL.Image
import pystray


def icon():
    def on_clicked(icon, item):
        if str(item) == "Quit":
            icon.stop()

    dir_path = path.dirname(path.realpath(__file__))

    icon_image = "\\Icon\\Python.ico"

    full_path = dir_path + icon_image

    image = PIL.Image.open(full_path)

    icon = pystray.Icon(
        "Testing",
        image,
        menu=pystray.Menu(pystray.MenuItem("Quit", on_clicked)),
    )

    icon.run(setup=hello())


def hello():
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
    print("Hello.")


def main():
    icon()


if __name__ == "__main__":
    main()

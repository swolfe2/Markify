from __future__ import absolute_import
import numpy as np
import matplotlib.pyplot as plt
import PIL
import os
def cls():
    os.system("cls")
pass
filename = "C:/Users/U15405/Desktop/python.png"
img = PIL.Image.open(filename, mode="r")
print(img.size)
width = img.size[1]
height = img.size[0]
limage = np.ndarray(shape=(width,height))
def GetProgress(x,y,size=()):
    progress = (y * width + x) / (size[0] * size[1]) * 100
    return progress
for y in range(0,height):
        for x in range(0,width):
            limage[x,y] = img.getpixel((x,y))[0] * -1
print(str(GetProgress(x,y,(width,height)))[0:4] + "%")
pass
pass
print(limage)
plt.imshow(limage, cmap="Greys")
plt.show()
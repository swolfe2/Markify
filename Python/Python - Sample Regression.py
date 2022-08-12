import numpy as np
from scipy.optimize import curve_fit
import matplotlib.pyplot as plt

x = [5.5, 6.0, 6.5, 7, 9]
y = [100, 80, 40, 10, 5]
popt, pcov = curve_fit(lambda fx, a, b: a * fx ** -b, x, y)
x_linspace = np.linspace(min(x), max(x), 100)
power_y = popt[0] * x_linspace ** -popt[1]

plt.scatter(x, y, label="actual data")
plt.plot(x_linspace, power_y, label="smooth-power-fit")
plt.legend()
plt.show()

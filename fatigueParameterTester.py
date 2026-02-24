import numpy as np
import matplotlib.pyplot as plt
#https://www.wattkg.com/power-records/

# Parameters
p1 = 52800.0      # fatigue threshold
px = 0      # initial fatigue
a = 0.00003     # fatigue rate
b = 0.0000002
T = 8200         # simulation length (seconds)

def fatigueSpeed(px, p1, a, t):
    return (355 + stamSpeed(t))* np.exp(-a * (px - p1))
def stamSpeed(t):
    breakAwayBonus = (531-355)
    return breakAwayBonus*np.exp(-1*b*breakAwayBonus*t)


times = []
speeds = []
fatigue = []

for t in range(T):
    if t >2000:
        if px < p1:
            current_speed = 355 + stamSpeed(t)
        else:
            current_speed = fatigueSpeed(px, p1, a, t)
    else:
        current_speed = 355
    
    if t==4000 or t==7000:
        px = 0

    if t==7200:
        print(current_speed, 355*1.33)

    
    times.append(t)
    speeds.append(current_speed)
    fatigue.append(px)
    px += current_speed - 355.0   # update fatigue

# ---- Plot 1: Speed ----
plt.figure()
plt.plot(times, speeds)
plt.xlabel("Time (seconds)")
plt.ylabel("Speed")
plt.title("Speed Over Time")
plt.show()

# ---- Plot 2: Fatigue ----
plt.figure()
plt.plot(times, fatigue)
plt.xlabel("Time (seconds)")
plt.ylabel("Fatigue")
plt.title("Fatigue Over Time")
plt.show()









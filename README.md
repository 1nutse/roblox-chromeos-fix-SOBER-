✨ Roblox Sober Fix
The seamless bridge for gaming on ChromeOS & FydeOS
<div align="center">


![alt text](https://img.shields.io/badge/Creator:-1nutse-blueviolet?style=for-the-badge&logo=github)


![alt text](https://img.shields.io/badge/SYSTEM-ChromeOS%20%7C%20FydeOS-2ea44f?style=for-the-badge&logo=linux)


![alt text](https://img.shields.io/badge/TARGET-Roblox%20(Sober)-ff0000?style=for-the-badge&logo=roblox)

</div>


![alt text](https://img.shields.io/badge/THE%20PROBLEM-Why%20it%20fails-red?style=for-the-badge)

If you have tried to play Roblox on your Chromebook using Sober, you likely hit two major roadblocks that make the game unplayable:

The Crash: The game refuses to open or crashes immediately due to graphical conflicts between X11 and Wayland.

The "Invisible Wall": You cannot turn your camera 360 degrees. The mouse hits the edge of the screen and stops dead, making it impossible to aim or look around.

![alt text](https://img.shields.io/badge/THE%20SOLUTION-How%20it%20works-success?style=for-the-badge)

This project by 1nutse fixes both issues instantly by stabilizing the game container.

Component	The Fix
🖥️ Rendering	We wrap the game in a Weston window. This creates a safe, stable graphical environment that prevents crashes.
🖱️ Mouse	We use active monitoring to gently "warp" the mouse to the opposite side before it hits the edge, allowing for infinite rotation.

![alt text](https://img.shields.io/badge/WHY%20USE%20THIS%3F-Benefits-blue?style=for-the-badge)

Zero Configuration: You don't need to be a Linux expert. It just works.

Fluid Gameplay: Spin, aim, and look around without your camera getting stuck.

Universal: Designed to work on both ChromeOS (Crostini) and FydeOS.

![alt text](https://img.shields.io/badge/QUICK%20GUIDE-3%20Steps-orange?style=for-the-badge)

Install: Run the provided script in your Linux terminal. This sets up the environment and installs the necessary lightweight tools.

Play: A new window will appear. Launch Sober, and it will automatically attach to this stable window.

Stop: When you are done playing, simply go back to your terminal window and press Ctrl + C to close the environment cleanly.

![alt text](https://img.shields.io/badge/NOTE-Friendly%20Tip-lightgrey?style=for-the-badge)

If you feel the camera do a tiny "jump" when looking all the way up or down, don't worry! This is a normal part of the trick to keep the mouse from getting trapped.

<div align="center">

Made by **1nutse**
</div>

# SuperTuxKart on the A7A

Launcher that pins the game to the two A76 big cores, pushes the desktop to the A55s,
and sets the performance governor (restoring it on exit).

    sudo cp supertuxkart-gpu /usr/local/bin/ && sudo chmod +x /usr/local/bin/supertuxkart-gpu
    supertuxkart-gpu

Install the game itself from Debian: `sudo apt install supertuxkart`

See [../../board-fixes/display-color/](../../board-fixes/display-color/) if colours look
inverted.

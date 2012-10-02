random-stuff
============

This is crap code, but sharing is caring, so DON'T JUDGE.

build-nova-images.sh
--------------------

Makes resizable nova images from minimal boostrap using debootstrap or mach.  Probably only works on debian, up to versions of fedora supported by the old febootstrap before the febootstrap author made it useless.  Supermin appliances?  What?

movedrill.py
------------

Ok.  So.  I had a PCB that had crap hanging off the side of the board.  When I generated drill gcode using pcb2gcode, I got drill locations at offsets based on the thing hanging off the side of the board.  That made it tough to zero my mill.  Since I didn't see anything in the googles within 30 seconds of searching, I made a stupid and naive drill code x & y translator.  Be aware this almost certainly is specific to pcb2gcode, and probably won't work for you unless you are really really lucky.  Test in sim, blah blah blah.

So, with a pcb that had and extra .071 added in the x direction, I can shift it over with something like:

    ./movedrill.py -i drill.gc -o new-drill.gc -x -.071 -y 0

That's it.  Really.

drill2ps.py
-----------

Given translating the gcode around, how can I see where the drills are going?  Again from the gcode (probably pcb2gcode only, makes bad assumptions, blah blah), it's not difficult to generate postscript output of the drill locations.  So that's what this does.  Usage:

    ./drill2ps.py new-drill.gc

Will drop a new-drill.ps that you can look at and print and line up with your PCB and make sure you are drilling crap in the right place.  0,0 is marked with a big cross for your lining-up benefit.

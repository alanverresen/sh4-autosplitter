# Silent Hill 4 Auto Splitter

This repository contains a small collection of auto splitters used by LiveSplit
for the game 'Silent Hill 4: The Room'.

* a room-based Any% auto splitter
* a world-based Any% auto splitter (future release)


## Install

### Getting The Files

To use one of these auto splitters with LiveSplit, extract the files from one
of the subdirectories to get started. Each subdirectory should contain:

* an *.asl file that contains the auto splitter script
* an *.lss file that contains the splits that go with the auto splitter script

Save these files locally, where you can easily access them.

### Making a New Layout

Start a new layout in LiveSplit, and add the following components:

* Timer > (Detailed) Timer
* List > (Sub)Splits
* Control > Scriptable Auto Splitter

If the auto splitter uses subsplits, you should use the subsplits component.

### Configuration

To add the auto splitter, open the 'Scriptable Auto Splitter' tab in the layout
settings menu, and add the script's filepath. This is the file with the .asl
file extension. If everything goes well, the greyed out boxes 'start', 'split',
and 'reset' should become selectable checkboxes. Make sure that all of these
are checked.

Silent Hill 4 speedruns use the in-game timer. To ensure that the in-game time
is used, set the following options in the layout settings:

* 'Splits > Columns > Column: +/- > Timing Method' = 'Game Time'
* 'Splits > Columns > Column: Time > Timing Method' = 'Game Time'
* 'Timer > Timing Method > Timing Method' = 'Game Time'

Now you can further change the layout settings to your liking. Done.

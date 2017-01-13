# GSPADR

Instructions for installation:

1. Install perl
2. use cpan to install:

Time::Timecode
XML::Writer

Instructions for editing:

1. Create a new audio track in protools. Give the track the name: GSPADR[SCENES] In the COMMENTS section of the track name, add parameters such as: FILM=Dicks Clinic, REEL=4, FPS=24 - these parameters will be used in the report.
2. Create blank clips in the GSPADR[SCENES] track that correspond to the scenes in the reel being edited. CMD-OPT-G CMD-SHIFT-R to create and rename the clip. Example name might be '37 INT. MEDITATION ROOM - MORNING-01'
3. Create multiple new mono audio tracks corresponding to the number of tracks that you want to use for reporting. Might be one track per character, ATMOS, MUSIC, SFX etc.... Each track should be named thus: MYTRACKNAME[GSPADR], for instance: DXDICKBOOM[GSPADR] or DXMARYLAV[GSPADR]. In the comments section, add the parameter CHARACTER={charactername}, for instance: CHARACTER=DICK or CHARACTER=MARY
4. In the "reporting" tracks, create clips (CMD-OPT-G CMD-SHIFT-R) and name them corresponding to the scripted dialogue for that shot. In Square Brackets, identify any issues that need to be repaired, for instance [rustle], [offmic] etc. for instance, a clip name might be: "you landed on me ... and.... you followed me home [background noise]", or 'No, you could never fly [offmic]'
5. Save and load this data along with your editing project.

Instruction for reporting:

1. Export Session Info as Text using the following parameters:

Include Track EDL's
Don't show crossfades
Time format: Timecode
File Format TextEdit 'TEXT'

Save as .txt file, for example reel1.txt

2. invoke the parser and save the output as an XML file:

./parse.pl reel1.txt > reel1.xml

3. open the XML file in Safari. Safari will apply the .css file in the directory for display purposes.

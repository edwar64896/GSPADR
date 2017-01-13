#!/usr/local/bin/perl
use strict;
use Data::Dumper;
use Time::Timecode;
use XML::Writer;

my $l;
my $key;
my $val;
my $key1;
my $val1;
my $tl=0;
my $ml=0;
my $ll;
my $title;
my $tkname;
my $inTrack=0;
my $inScenes=0;
my $inEventList=0;
my $trackComment;
my $comment;
my $parameter;
my $value;
my $evtId;
my @evt;
my @commentArray;
my %tracks;
my %chartotals;

sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s };
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s };
sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

open (FILE1, $ARGV[0]);
while (<FILE1>) {
	chomp;
	if (m/T R A C K  L I S T I N G/) { $tl=1; $ml=0; }
	if (m/M A R K E R S  L I S T I N G/) { $ml=1; $tl=0; }
	if ($tl==1) {
		if (m/TRACK NAME/) {
			($title, $tkname) = split(/\t/);
			if ($tkname =~ m/GSPADR\[SCENES\]/) {
				$inScenes=1;
				$inTrack=0;
			}
			if ($tkname =~ m/\[GSPADR\]$/) {
				$tkname =~ s/\[GSPADR\]//g;
				$inTrack=1;
				$inScenes=0;
			}
		}

#
# collect Scene information from regions in the GSPADR[SCENES] track
#
		if ($inScenes==1) {
			if (m/COMMENTS:/) {
				($title, $trackComment) = split (/\t/);
				@commentArray = split (/,/, $trackComment);
				foreach my $comment (@commentArray) {
					($parameter,$value)=split (/=/,$comment);
					$tracks{'parameters'}{trim($parameter)}=trim($value);
				}
			}
			if (m/^$/) {$inScenes=0;$inEventList=0;}
			if ($inEventList==1) {
				@evt=split(/\t/);
				$evtId=trim(@evt[1]);
				$tracks{'scenes'}{$evtId}{'SCENENAME'}=trim(@evt[2]);
				$tracks{'scenes'}{$evtId}{'START'}=ltrim(@evt[3]);
				$tracks{'scenes'}{$evtId}{'END'}=ltrim(@evt[4]);
				$tracks{'scenes'}{$evtId}{'DURATION'}=ltrim(@evt[5]);
				$tracks{'scenes'}{$evtId}{'STATE'}=@evt[6];
			}
			if (m/CHANNEL/) {$inEventList=1;}
		}
#
# collect ADR information from regions in any track with [GSPADR] appended to the trackname
#
		if ($inTrack==1) {
			if (m/COMMENTS:/) {
				($title, $trackComment) = split (/\t/);
				@commentArray = split (/,/, $trackComment);
				foreach my $comment (@commentArray) {
					($parameter,$value)=split (/=/,$comment);
				}
			}
			if (m/^$/) {$inTrack=0;$inEventList=0;}
			if ($inEventList==1) {
				@evt=split(/\t/);
				$evtId=trim(@evt[1]);
				$tracks{'tracks'}{$tkname}{$evtId}{'CLIPNAME'}=trim(@evt[2]);
				$tracks{'tracks'}{$tkname}{$evtId}{'START'}=ltrim(@evt[3]);
				$tracks{'tracks'}{$tkname}{$evtId}{'END'}=ltrim(@evt[4]);
				$tracks{'tracks'}{$tkname}{$evtId}{'DURATION'}=ltrim(@evt[5]);
				$tracks{'tracks'}{$tkname}{$evtId}{'STATE'}=@evt[6];
				$chartotals{$tkname}+=getFrames($tracks{'tracks'}{$tkname}{$evtId}{'DURATION'});
				foreach my $comment (@commentArray) {
					($parameter,$value)=split (/=/,$comment);
					$tracks{'tracks'}{$tkname}{$evtId}{trim($parameter)}=trim($value);
				}
			}
			if (m/CHANNEL/) {$inEventList=1;}
		}
	}
}



#
# process data
# 

#
# helper to pull out frames from a timecode value
#
sub getFrames {
	my $inTC=shift;
	my $fps=25;
	if (exists $tracks{'parameters'}{'FPS'}) {
		$fps=$tracks{'parameters'}{'FPS'};
	}
	my $inTC1=Time::Timecode->new($inTC,{'fps'=>$fps});

	return $inTC1->total_frames;
}

#
# helper to pull out frames from a timecode value
#
sub framesToTC {
	my $inframes=shift;
	my $fps=25;
	if (exists $tracks{'parameters'}{'FPS'}) {
		$fps=$tracks{'parameters'}{'FPS'};
	}
	my $inTC1=Time::Timecode->new($inframes,{'fps'=>$fps});

	return $inTC1;
}

#
# identify where :ADR: notes appear within the scene boundaries
#

sub searchScenes {
	my $inTc=shift;
	my $scenesArray=$tracks{'scenes'};
	my @keys=sort { $scenesArray->{$a} <=> $scenesArray->{$b} } keys(%$scenesArray);
	while ( (my $key5, my $val5) = each (@keys)) {
		my $tcStart=Time::Timecode->new($scenesArray->{$val5}->{'START'},{'fps'=>$tracks{'parameters'}{'FPS'}});
		my $tcEnd=Time::Timecode->new($scenesArray->{$val5}->{'END'},{'fps'=>$tracks{'parameters'}{'FPS'}});
		if ($tcStart->total_frames <= $inTc->total_frames && $inTc->total_frames <= $tcEnd->total_frames) {
			return $val5;
		}
	}
	return ;
}

#
# Iterate through the "Tracks" and align "clips" with "Scenes".
# Insert clip information into each scene block so that we can easily sort by both scene and character.
#
my $tid=0;
my $tx=$tracks{'tracks'};

#print Dumper(\$tx);

#while ((my $key2, my $val2) = each ($tracks{'tracks'})) {
while ((my $key2, my $val2) = each (%$tx)) {
	my @keys=sort { $val2->{$a} <=> $val2->{$b} } keys(%$val2);

	while ( (my $key3,my $val3) = each (@keys)) {
		#if ($key3 == "0") {next;} #0 key appears during sort - skip it.
		my $tcStart=Time::Timecode->new($val2->{$val3}->{'START'},{'fps'=>$tracks{'parameters'}{'FPS'}});
		my $retScene=searchScenes($tcStart);
		if ($retScene != "") {
			$tracks{'tracks'}{$key2}{$val3}{'SCENENAME'}=$tracks{'scenes'}{$retScene}{'SCENENAME'};
			#
			# populate the scenes hash with all the clips data.
			#
			$tracks{'scenes'}{$retScene}{'LINES'}{$tracks{'tracks'}{$key2}{$val3}{'CHARACTER'}}{$tid++} = $tracks{tracks}{$key2}{$val3};
		}
	}
}

#print Dumper(\%tracks);
#print Dumper(\%chartotals);

my $writer=new XML::Writer(NEWLINES=>1);
$writer->pi('xml','version="1.0" encoding="UTF-8"');
$writer->pi('xml-stylesheet','href="./style.css" type="text/css"');
$writer->startTag("gspadr");

$writer->startTag("film",
	"name"=>$tracks{'parameters'}{'FILM'},
	"reel"=>$tracks{'parameters'}{'REEL'},
	"fps"=>$tracks{'parameters'}{'FPS'}
);
	
	
$writer->endTag("film");

$writer->startTag("scenes");

#
# Iterate through the scenes
#
my %scenes=%{$tracks{'scenes'}};
	
	#
	# sort the scenes based on the start time
	#
	#my @keys=sort { getFrames($val2->{$a}->{START}) <=> getFrames($val2->{$b}->{START}) } keys(%$val2);
	my @keys=sort { getFrames($scenes{$a}{'START'}) <=> getFrames($scenes{$b}{'START'}) } keys(%{ $tracks{'scenes'}});

	while ( (my $key3,my $val3) = each (@keys)) {

		my $szLines=0;

		if (exists $scenes{$val3}{'LINES'}) {
			my %kLines=$scenes{$val3}{'LINES'};
			my @kLines=keys(%kLines);
			$szLines=@kLines;
		}

		if ($szLines>0) {

		$writer->startTag("scene",
			"scenename"=>$scenes{$val3}{'SCENENAME'},
			"numcharacters"=>$szLines
		);

		$writer->startTag("time",
			"duration"=>$scenes{$val3}{'DURATION'},
			"start"=>$scenes{$val3}{'START'},
			"end"=>$scenes{$val3}{'END'}
			);
		$writer->endTag("time");

		#
		# each scene has a number of characters for ADR purposes
		#

		$writer->startTag("characters");
			
		my %characters=%{$scenes{$val3}{'LINES'}};
		#my @charKeys=sort { $val2->{$a} <=> $val2->{$b} } keys(%characters);
		my @charKeys=sort { $scenes{$a} <=> $scenes{$b} } keys(%characters);
		while ((my $key4,my $val4) = each (@charKeys)) {
			
			$writer->startTag("character",
				"charactername"=>$val4
				);
			$writer->startTag("lines");
			my %lines=%{$characters{$val4}};
			my @lineKeys=sort { $scenes{$a} <=> $scenes{$b} } keys(%lines);
			while ((my $key5,my $val5) = each (@lineKeys)) {
				$writer->startTag("line",
				"dialogue"=>$lines{$val5}{'CLIPNAME'}
				);
					$writer->startTag("time",
					"duration"=>$lines{$val5}{'DURATION'},
					"start"=>$lines{$val5}{'START'},
					"end"=>$lines{$val5}{'END'}
					);
					$writer->endTag("time");
				$writer->endTag("line");
			}

			$writer->endTag("lines");
			$writer->endTag("character");
			
		}
			
			
		$writer->endTag("characters");
		$writer->endTag("scene");
		}
	}

$writer->endTag("scenes");

$writer->startTag("clips");

my %tks=%{$tracks{'tracks'}};
#while ((my $key2, my $val2) = each ($tracks{'tracks'})) {
while ((my $key2, my $scenes) = each (%tks)) {

	$writer->startTag("track","name" => $key2,
		"duration"=>framesToTC($chartotals{$key2}));
	my @keys=sort { getFrames($scenes->{$a}->{START}) <=> getFrames($scenes->{$b}->{START}) } keys(%$scenes);

	while ( (my $key3,my $val3) = each (@keys)) {
		$writer->startTag("clip",
			"line"=>$scenes->{$val3}->{'CLIPNAME'},
			"character"=>$scenes->{$val3}->{'CHARACTER'},
			"scene"=>$scenes->{$val3}->{'SCENENAME'}
		);
		$writer->startTag("time",
			"duration"=>$scenes->{$val3}->{'DURATION'},
			"start"=>$scenes->{$val3}->{'START'},
			"end"=>$scenes->{$val3}->{'END'}
		);
		$writer->endTag("time");
		$writer->endTag("clip");
	}
	$writer->endTag("track");
}
$writer->endTag("clips");


$writer->endTag("gspadr");
$writer->end();

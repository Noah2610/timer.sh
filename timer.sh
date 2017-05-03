#!/bin/bash

defCmd="cvlc"
cmd=$defCmd
defAlarm="/home/noah/Music/alarm.mp3"
alarm=$defAlarm
helpFile="/home/noah/Projects/shell/timer/help.txt"
Opts=("$@")
format="m.s"
outFormat=
time=0
timeSec=0
execTimer=true
sleepDur=1

if [ $# -gt 0 ]; then

	# get options
	for (( count = 0; count < $#; count++ )); do
		opt=${Opts[$count]}

		if [ -n "${Opts[$count + 1]}" ]; then
			val=${Opts[$count + 1]}
		fi

		if [ ${opt:0:1} == "-" ]; then
			if [[ ${opt:1:1} == "h" ]]; then  # help
				cat $helpFile
				exit
			elif [[ ${opt:1:1} == "f" ]]; then  # format
				format=$val
			elif [[ ${opt:1:1} == "o" ]]; then  # output format
				outFormat=$val
			elif [[ ${opt:1:1} == "t" ]]; then  # in
				time=$val
			elif [[ ${opt:1:1} == "w" ]]; then  # wait / sleep duration
				sleepDur=$val
			elif [[ ${opt:1:1} == "C" ]]; then  # custom command
				cmd=$val
			elif [[ ${opt:1:1} == "A" ]]; then  # custom audio file
				if [ "$cmd" != "$defCmd" ]; then
					echo -e "setting a custom audio file has no effect in conjunction with using a custom command\nignoring custom audio file"
					read -n1
				elif [[ -f "$val" && ( $val == *".mp3" || $val == *".wav" || $val == *".m4a" ) ]]; then
					alarm=$val
				else
					echo "$val is not a file, using default alarm ($defAlarm)"
					read -n1
				fi
			fi
		fi
	done

	# use format as output if no ouput format given
	if [ -z "$outFormat" ]; then
		outFormat=$format
	fi

	# create timer with options
	# compare $time with $format
	timeArr=($(echo $time | sed 's/\([ [:punct:]]\)/ \1 /g'))
	for (( count = 0; count < ${#timeArr[@]}; count++ )); do
		inCur=${timeArr[$count]}
		fCur=${format:$count:1}

		case "$fCur" in
			# TIME:
			"s")  # seconds
				if [ "$inCur" -eq "$inCur" ]; then
					timeSec=$(echo "$timeSec + $inCur" | bc)
				fi
				;;
			"m")  # minutes
				if [ "$inCur" -eq "$inCur" ]; then
					timeSec=$(echo "$timeSec + ($inCur * 60)" | bc)
				fi
				;;
			"h")  # hours
				if [ "$inCur" -eq "$inCur" ]; then
					timeSec=$(echo "$timeSec + ($inCur * 3600)" | bc)
				fi
				;;
			# might add DAY, MONTH (and maybe YEAR) here eventually
			# SEPERATOR:
		esac
	done

	echo $timeSec

	# execute timer
	if [ $execTimer ]; then
		startTime=$(date +%s)
		endTime=$(echo "$startTime + $timeSec" | bc)
		for (( count = 0; count < $timeSec; count++ )); do
			clear

			# calculate times
			remSec=$(echo "$endTime - $(date +%s)" | bc)
			min=
			hour=
			if [[ "$outFormat" == *"h"* ]]; then  # hours
				hour=$(echo "$remSec / 3600" | bc)
				remSec=$(echo "$remSec % 3600" | bc)
			fi
			if [[ "$outFormat" == *"m"* ]]; then  # minutes
				min=$(echo "$remSec / 60" | bc)
				remSec=$(echo "$remSec % 60" | bc)
			fi
			sec=$remSec

			# necessary to print remaining time in $outFormat
			for (( countF = 0; countF < ${#outFormat}; countF++ )); do
				cur=${outFormat:$countF:1}
				case "$cur" in
					"s")
						if [[ ${#sec} -lt 2 ]]; then echo -n "0"; fi
						echo -n "$sec"
						;;
					"m")
						if [[ ${#min} -lt 2 ]]; then echo -n "0"; fi
						echo -n "$min"
						;;
					"h")
						if [[ ${#hour} -lt 2 ]]; then echo -n "0"; fi
						echo -n "$hour"
						;;
					*)
						echo -n "$cur"
				esac
			done

			if [[ "$outFormat" != *"s"* ]]; then
				echo -n ".$sec s"
			fi

			sleep $sleepDur;
		done

		clear
		echo "Time's Up!"
		if [ "$cmd" == "$defCmd" ]; then
			$cmd "$alarm"
		else
			bash -c "$cmd"
		fi
	fi
fi

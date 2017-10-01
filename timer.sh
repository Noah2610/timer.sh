#!/bin/bash

defPath="/home/noah/Projects/shell/timer"
defCmd="cvlc --play-and-exit -q"
cmd="$defCmd"
defAlarm="$defPath/alarm.mp3"
alarm="$defAlarm"
helpFile="$defPath/help.txt"
Opts=("$@")
format="m.s"
outFormat=
time=0
timeSec=0
execTimer=true
sleepDur=1
milli=
defOutput="/dev/stdout"
output="$defOutput"
i3statusPath="/home/noah/.bar_output"
i3statusOutput=
#i3statusFormat="Timer: %m:%s"
i3statusFormat="%m:%s"
i3icons=( "" "" )
i3iconCurFront=0
i3iconCurBack=1
newOpts=
bgOutputPath="/home/noah/.remaining_time"
bgSetOutput=
#popoutCmd="termite --role FLOAT -e 'bash -c \'echo\ Time\"\'\"s\ Up!\;\ \"$cmd\"\ \"$alarm\"\'"
popoutCmd="termite --role FLOAT -e \"bash -c 'echo Time´s Up!; $cmd $alarm'\""
inBg=


if [ $# -gt 0 ]; then

	# get options
	for (( count = 0; count < $#; count++ )); do
		opt="${Opts[$count]}"

		if [ -n "${Opts[$count + 1]}" ]; then
			val="${Opts[$count + 1]}"
		fi

		if [ "${opt:0:1}" == "-" ]; then
			if [[ ${opt:1:1} == "h" ]]; then  # help
				cat $helpFile
				exit
			elif [[ "${opt:1:1}" == "f" ]]; then  # format
				format="$val"
			elif [[ "${opt:1:1}" == "o" ]]; then  # output format
				outFormat="$val"
			elif [[ "${opt:1:1}" == "t" ]]; then  # in
				time=$( echo -n "$val" | tr -d "\"" )
			elif [[ "${opt:1:1}" == "w" ]]; then  # wait / sleep duration
				sleepDur="$val"
			elif [[ "${opt:1:1}" == "C" ]]; then  # custom command
				cmd="$val"
			elif [[ "${opt:1:1}" == "A" ]]; then  # custom audio file
				if [ "$cmd" != "$defCmd" ]; then
					echo -e "setting a custom audio file has no effect in conjunction with using a custom command\nignoring custom audio file"
					read -n1
				elif [[ -f "$val" && ( "$val" == *".mp3" || "$val" == *".wav" || "$val" == *".m4a" ) ]]; then
					alarm="$val"
				else
					echo "$val is not a file, using default alarm ($defAlarm)"
					read -n1
				fi
			elif [[ "${opt:1:1}" == "m" ]]; then  # display milliseconds
				milli=$val
			elif [[ "${opt:1:1}" == "O" ]]; then  # set output path
				output=$val
			elif [[ "${opt:1:1}" == "B" ]]; then  # display remaining time in i3 status bar (with my config)
				i3statusOutput=true
				output="$i3statusPath"
				inBg=true
			elif [[ "${opt:1:1}" == "b" ]]; then  # restart timer in background
				bgSetOutput=true
				inBg=true
			elif [[ "${opt:1:1}" == "P" ]]; then  # create new terminal window with alarm playing when timer finishes (popout)
				cmd="$popoutCmd"
			fi
		fi
	done

	# set output path to i3 status bar custom output (mainly for starting in bg, workaround)
	if [ "$output" == "$i3statusPath" ]; then
		i3statusOutput=true
	fi

	# set output path if non set and if timer should restart in bg
	if [[ -n "$bgSetOutput" && "$output" == "$defOutput" ]]; then
		newOpts[${#newOpts[@]}]="-O"
		newOpts[${#newOpts[@]}]="$bgOutputPath"
	fi

	# restart in bg
	if [ -n "$inBg" ]; then
		finalOpts=()
		# check for -b or -B opts in newOpts to avoid infinite application starting recursion
		for (( count = 0; count < ${#Opts[@]}; count++ )); do
			skip=false
			if [[ "${Opts[$count]:0:1}" == "-" ]]; then
				if [[ "${Opts[$count]:1:1}" != "b" && "${Opts[$count]:1:1}" != "B" ]]; then
					finalOpts[${#finalOpts[@]}]="${Opts[$count]}"
				fi
				skip=true
			fi
			if [ "$skip" == "false" ]; then
				finalOpts[${#finalOpts[@]}]="${Opts[$count]}"
			fi

		done
		extraOpts=
		if [ -n "$i3statusOutput" ]; then
			extraOpts=("-O" "$i3statusPath")
		fi
		# restart script
		${defPath}/timer.sh "${finalOpts[@]}" "${extraOpts[@]}" "-P" &
		exit
	fi


	if [ -z "$outFormat" ]; then
		# set output format for timer in i3status if no custom format is set
		if [ -n "$i3statusOutput" ]; then
			outFormat="$i3statusFormat"

		else
			# else use format as output
			outFormat=$format
		fi

	fi


	# create timer with options
	# compare $time with $format
	timeArr=($( echo -n "$time" | sed 's/\([ [:punct:]]\)/ \1 /g' ))
	for (( count = 0; count < ${#timeArr[@]}; count++ )); do
		inCur=${timeArr[$count]}
		fCur="${format:$count:1}"

		case "$fCur" in
			# TIME:
			"s")  # seconds
				if [ $inCur -eq $inCur ]; then
					timeSec=$(echo "$timeSec + $inCur" | bc)
				fi
				;;
			"m")  # minutes
				if [ $inCur -eq $inCur ]; then
					timeSec=$(echo "$timeSec + ($inCur * 60)" | bc)
				fi
				;;
			"h")  # hours
				if [ $inCur -eq $inCur ]; then
					timeSec=$(echo "$timeSec + ($inCur * 3600)" | bc)
				fi
				;;
			# might add DAY, MONTH (and maybe YEAR) here eventually
			# SEPERATOR:
		esac
	done

	# execute timer
	if [ -n "$execTimer" ]; then
		startTime=$(date +%s)
		endTime=$(echo "$startTime + $timeSec" | bc)
		while [ $(date +%s) -lt $endTime ]; do
			echo -n "" > $output
			if [ "$output" == "$defOutput" ]; then clear; fi

			# echo fontawesome icons in output to i3status
			if [ -n "$i3statusOutput" ]; then
				echo -n "${i3icons[$i3iconCurFront]} " >> $output
				i3iconCurFront=$( echo "$i3iconCurFront + 1" | bc )
				if [ $i3iconCurFront -gt 1 ]; then
					i3iconCurFront=0
				fi
			fi

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
				cur="${outFormat:$countF:1}"
				if [[ "$format" == "$outFormat" || "$cur" == "%" ]]; then
					caseCur=
					if [ "$cur" == "%" ]; then
						caseCur="${outFormat:$countF+1:1}"
					else
						caseCur="$cur"
					fi
					case "$caseCur" in
						"s")
							if [[ ${#sec} -lt 2 ]]; then echo -n "0" >> $output; fi
							echo -n "$sec" >> $output
							;;
						"m")
							if [[ ${#min} -lt 2 ]]; then echo -n "0" >> $output; fi
							echo -n "$min" >> $output
							;;
						"h")
							if [[ ${#hour} -lt 2 ]]; then echo -n "0" >> $output; fi
							echo -n "$hour" >> $output
							;;
						*)
							echo -n "$cur" >> $output
					esac
				elif [[ "${outFormat:${countF}-1:1}" != "%" ]]; then
					echo -n "$cur" >> $output
				fi
			done

			if [[ "$outFormat" != *"s"* ]]; then
				echo -n ".$sec s" >> $output
			fi
			if [[ "$milli" != "" ]]; then
				echo -n " ,$(date +%N | cut -c1-$milli) ms" >> $output
			fi

			# echo fontawesome icons in output to i3status
			if [ -n "$i3statusOutput" ]; then
				echo -n " ${i3icons[$i3iconCurBack]}" >> $output
				i3iconCurBack=$( echo "$i3iconCurBack + 1" | bc )
				if [ $i3iconCurBack -gt 1 ]; then
					i3iconCurBack=0
				fi
			fi

			sleep $sleepDur
		done

		if [ "$output" == "$defOutput" ]; then clear; fi
		echo "Time's Up! ($time)" > $output
		if [ "$cmd" == "$defCmd" ]; then
			$cmd "$alarm"
		else
			bash -c "$cmd" >> $output
		fi
		echo -n "" > $output
	fi
fi

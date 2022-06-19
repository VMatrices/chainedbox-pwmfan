#!/bin/bash

VERSION=1.0
pid_file=/var/run/pwm-fan.pid

. /etc/pwm-fan.conf

# Enable fan power, and initialize pwm parameters
function init_fan {
	if [[ ! -d /sys/class/pwm/pwmchip0/pwm0 ]]; then
		echo 0 >/sys/class/pwm/pwmchip0/export
	fi
	echo $PWM_PERIOD >/sys/class/pwm/pwmchip0/pwm0/period
	echo normal >/sys/class/pwm/pwmchip0/pwm0/polarity
	echo 0 >/sys/class/pwm/pwmchip0/pwm0/duty_cycle
	echo 1 >/sys/class/pwm/pwmchip0/pwm0/enable
	echo 1 >/sys/class/leds/fanpower/brightness
}

# Disable fan power, and reset pwm parameters
function stop_fan {
	if [[ -d /sys/class/pwm/pwmchip0/pwm0 ]]; then
		echo 0 >/sys/class/pwm/pwmchip0/pwm0/enable
		echo 0 >/sys/class/pwm/pwmchip0/unexport
		echo 0 >/sys/class/leds/fanpower/brightness
		echo Fan stopeed
	else
		echo Fan is not working
	fi
}

# Read and convert cpu temperature from thermal_zone0
function read_cpu_temp {
	raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
	echo $(expr $raw_temp / 1000)
}

# Read disk temperature
function read_disk_temp {
	if [[ -n $DISK ]]; then
		echo $(smartctl -l scttempsts $DISK 2>/dev/null | grep -i 'Current Temperature:' | awk '{print $(NF-1)}')
	fi
}

# Read and convert cpu temp from thermal_zone0
function calc_fan_speed {
	temp=$1
	if [[ $temp -lt $MIN_TEMP ]]; then
		echo $MIN_SPEED
		return
	fi
	if [[ $temp -gt $MAX_TEMP ]]; then
		echo $MAX_TEMP
		return
	fi

	temp_duty=$(expr $temp - $MIN_TEMP)
	temp_range=$(expr $MAX_TEMP - $MIN_TEMP)
	speed_range=$(expr $MAX_SPEED - $MIN_SPEED)
	echo $(expr $MIN_SPEED + $temp_duty \* $speed_range / $temp_range)
}

# Set the pwm duty_cycle by percentage offerd
function set_fan_speed {
	speed_percent=$1
	if [[ $speed_percent -gt 100 ]]; then
		speed_percent=100
	fi
	duty_cycle=$(expr $PWM_PERIOD \* $speed_percent / 100)
	echo $duty_cycle >/sys/class/pwm/pwmchip0/pwm0/duty_cycle
}

function print_line {
	echo "------------------------------------------------"
}

function print_header {
	print_line
	echo " Auto PWM Fan Script For Chainedbox LP1 v$VERSION"
	echo " Created By: iBelieve (umatrix@outlook.com)"
}

function print_param {
	print_line
	echo -e " Temp Rang:          $MIN_TEMP ~ $MAX_TEMP °C"
	echo -e " Fan Speed Range:        $MIN_SPEED ~ $MAX_SPEED %"
	echo -e " Fan Stopped temp:       $STOP_TEMP °C"
	echo -e " Watch Interval Time:    ${WATCH_INTERVAL}s"
	if [[ -n "$(read_cpu_temp)" ]]; then
		echo -e " Watch Disk:             ${DISK}s"
	fi
	print_line
}

function print_log {
	echo -e "$(date +"%Y-%m-%d %H:%M:%S") - $1"
}

# Main cycle
function main {
	echo -e "PWM Fan is running ...\n"
	enable_log=$1
	init_fan
	fan_speed=0
	last_temp=0

	while true; do
		cpu_temp=$(read_cpu_temp)
		disk_temp=$(read_disk_temp)
		raw_temp=$cpu_temp
		if [[ -n "$disk_temp" && $disk_temp -gt $raw_temp ]]; then
			raw_temp=$disk_temp
		fi

		fuzzy_temp=$(expr $raw_temp / $TEMP_INTERVAL \* $TEMP_INTERVAL)

		# If the temperature does not change, do not process
		if [[ $fuzzy_temp != $last_temp ]]; then
			last_temp=$fuzzy_temp

			if [[ $fuzzy_temp -lt $STOP_TEMP ]]; then
				fan_speed=0
			elif [[ $fuzzy_temp -lt $MIN_TEMP && $fan_speed = 0 ]]; then
				fan_speed=0
			else
				fan_speed=$(calc_fan_speed $fuzzy_temp)
			fi
			set_fan_speed $fan_speed

			if [[ $enable_log = 1 ]]; then
				log="Cpu Temp: $cpu_temp°C"
				if [[ -n "$disk_temp" ]]; then
					log="$log, Disk Temp: $disk_temp°C"
				fi
				log="$log, Fan Speed: "
				if [[ $fan_speed = 0 ]]; then
					log="${log}Stopped"
				else
					log="${log}${fan_speed}%"
				fi
				print_log "$log"
			fi
		fi

		sleep ${WATCH_INTERVAL}s
	done
}

# Kill process
function stop_proc {
	if [[ -f $pid_file ]]; then
		pid=$(cat $pid_file)
		echo "Kill process: $pid"
		kill $pid
		rm $pid_file
	fi
}

function start {
	echo
	if [[ -f $pid_file ]]; then
		echo "PWM Fan is already running!"
		stop_proc
	fi

	print_header
	print_param

	if [[ $PWM_FAN_DEAMON_MODE = 1 ]]; then
		echo $$ >$pid_file
		main 0
	else
		main 1
	fi
}

case $1 in
"start")
	start
	;;
"stop-fan")
	stop_fan
	;;
"start-daemon")
	export PWM_FAN_DEAMON_MODE=1
	echo Startting with deamon mode ....
	$0 start &
	;;
"stop")
	stop_proc
	stop_fan
	;;
*)
	print_header
	print_line
	echo " Usage For Systemd:"
	echo "   systemctl (start|stop|reload) pwm-fan.service"
	print_line
	echo " Usage For Terminal (Not Recommend):"
	echo "   Normal Mode: pwm-fan (start|stop-fan)"
	echo "   Daemon Mode: pwm-fan (start-deamon|stop)"
	print_line
	;;
esac

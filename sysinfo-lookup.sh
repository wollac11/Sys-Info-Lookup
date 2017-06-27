#!/bin/bash

# Intro header
print_info() {
	echo "-----------------------
----SYS INFO LOOKUP----
------Version 1.0------
--Charlie Callow 2017--
-----------------------
"
}

# Prints supported input options
print_help() {
    echo "-h | --help               	: See this options list"
    echo "-a | --about              	: View version info"
    echo "-s | --serial [serial no.]	: Lookup model from Apple serial"
    echo "-d | --ondevice           	: Get system info for current machine"
    echo "-r | --remote [user@host] 	: Get system info for remote machine"
}

# Requests serial from user
req_serial() {
	echo -n "Please enter Apple serial number: "
	read serial
}

# Looks up model from Apple serial
check_serial() {
	# Remove first 8 chars
	ser_end=$(echo "${serial}" | cut -c 9-)

	# Lookup & output model
	echo -n "Model: "
	curl -s http://support-sp.apple.com/sp/product?cc=${ser_end} | awk -v FS="(<configCode>|</configCode>)" '{print $2}'
}

# Evaluates expression and rounds result
round() {
    # $1 is expression to round (should be a valid bc expression)
    # $2 is number of decimal figures (optional). Defaults to three if none given
    local df=${2:-3}
    printf '%.*f\n' "$df" "$(bc -l <<< "a=$1; if(a>0) a+=5/10^($df+1) else if (a<0) a-=5/10^($df+1); scale=$df; a/1")"
}

# Converts Unixtime to DDHHMM
display_time() {
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	printf '%d days, ' $D
	printf '%d hours, ' $H
	printf '%d minutes.\n' $M
}

# Gets system info about Linux & other non-Apple Unix systems
linux_info() {
	# Try sudo
	sudo echo &> /dev/null

	# Get system manufacturer
	vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor)
	# Fallback to motherboard manufacturer if product manufacturer unavailable
	if [[ $vendor = *[!\ ]* ]]; then
		echo "System Manufacturer: ${vendor}" 
	else
		echo "MB Manufacturer: $(cat /sys/devices/virtual/dmi/id/board_vendor)"
	fi 

	# Get system product name
	product=$(cat /sys/devices/virtual/dmi/id/product_name)
	# Fallback to motherboard model if product model unavailable
	if [[ $product = *[!\ ]* ]]; then
		echo "Model: ${product}" 
	else
		echo "MB Model: $(cat /sys/devices/virtual/dmi/id/board_name)" 
	fi

	# Get system serial
	serial=$(sudo cat /sys/devices/virtual/dmi/id/product_serial)
	# Fallback to motherboard serial if product serial unavailable
	if [[ $serial = *[!\ ]* ]]; then
		echo "Serial: ${serial}" 
	else
		echo "MB Serial: $(sudo cat /sys/devices/virtual/dmi/id/board_serial)" 
	fi

	# Output OS distrubtion name & version
	echo "OS: $(lsb_release -a 2>/dev/null | grep "Description" | awk '{ for( i=2 ; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')"
	
	# Output system kernel version
	echo "Kernel: $(uname -mrs)"

	# Output CPU model and core/thread count
	cpu_model=$(grep -m 1 "model name" /proc/cpuinfo |  awk '{ for( i=4 ; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	cpu_count=$(cat /proc/cpuinfo | grep processor | wc -l)
	echo "CPU: ${cpu_model}x ${cpu_count}"

	# Calculate total memory
	total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
	if [ "${total_mem}" -ge "2000000" ]; then
		total_mem=$(round ""$total_mem"/1000000" "0")
	else
		total_mem=$(round ""$total_mem"/1000000" "1")
	fi
	# Calculate free memory
	free_mem=$(vmstat -s | grep "free memory" | awk '{print $1}')
	free_mem=$((free_mem/1024))
	# Output system memory details
	echo "Mem Total: ${total_mem} GB"
	echo "Mem Free: ${free_mem} MB"

	# Output disk model
	hdd_model=$(sudo smartctl -i /dev/sda | grep Family | awk '{ for( i=3; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	echo "Disk Model: ${hdd_model}"
	
	# Calculate disk usage for common partitions
	free_root=$(df -BG / | grep / | awk '{print $4}')
	free_home=$(df -BG /home | grep / | awk '{print $4}')
	free_scratch=$(df -BG /scratch 2>/dev/null | grep / | awk '{print $4}')
	# Calculate disk capacity
	total_hdd=$(lsblk -b --output SIZE -n -d /dev/sda)
	total_hdd=$((${total_hdd}/1000000000))
	# Output disk stats
	echo "Disk Size: ${total_hdd} GB"
	echo -n "Disk Free: ${free_root//[!0-9]/} GB ROOT, ${free_home//[!0-9]/} GB HOME"
	# Output notification if no scratch partition found
	if [ $free_scratch ]; then
		echo ", ${free_scratch//[!0-9]/} GB SCRATCH"
	else
		echo "." && echo "           No scratch partition found."
	fi

	# Output type of storage medium in use for primary disk
	echo -n "Disk Type: "
	hdd_bool=$(cat /sys/block/sda/queue/rotational)
	if [ $hdd_bool == "1" ]; then
		echo "Rotational"
		hdd_rpm=$(sudo hdparm -I /dev/sda | grep Rotation | awk '{print $5}')
		# If drive is a rotational disk, output its RPM
		if [[ "${hdd_rpm}" ]]; then 
			echo "Disk Rotation Speed: ${hdd_rpm} RPM" 
		fi
	else
		echo "Solid State"
	fi

	# Check drive S.M.A.R.T. Health
	hdd_health=$(sudo smartctl -H /dev/sda | grep "overall-health" | awk '{print $6}')
	echo "SMART Status: ${hdd_health}"

	# Get system installation date
	echo -n "System Installed: "
	sudo tune2fs -l /dev/sda1 | grep created | awk '{print $5, $4, $7}'

	# Calculate system uptime
	seconds=$(cat /proc/uptime | awk '{print $1}')
	seconds=${seconds%.*}
	# Output system uptime in hours, mins and days
	echo -n "Uptime: "
	echo $((seconds/86400))" days,"\
     $(date -d "1970-01-01 + $seconds seconds" "+%H hours, %M minutes.")

    # Get list of logged in users
    pc_users=$(users)
    # Remove duplicate entries for users with multiple sessions
	declare -A uniq
	for k in $pc_users ; do uniq[$k]=1 ; done
	# Output list of users logged into machine
	echo -n "Users Logged In: "
	if [[ ${!uniq[@]} ]]; then
		echo ${!uniq[@]}
	else
		echo "None"
	fi
}

mac_info() {
	echo "Manufacturer: Apple Inc."

	# Obtain serial from system
	serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	# Get model from serial
	check_serial
	# Display serial
	echo "Serial: ${serial}"

	# Output OS version from system
	os_ver=$(sw_vers -productVersion)
	echo -n "OS: ${os_ver} "
	# Lookup & output marketing name for OS release
	curl -s http://support-sp.apple.com/sp/product?edid=${os_ver} | awk -v FS="(<configCode>|</configCode>)" '{print $2}'
	
	# Output system kernel version
	echo "Kernel: $(uname -mrs)"

	# Output CPU model	
	echo -n "CPU: "
	sysctl -n machdep.cpu.brand_string

	# Calculate 'free' memory
	free_blocks=$(vm_stat | grep free | awk '{ print $3 }' | sed 's/\.//')
	speculative_blocks=$(vm_stat | grep speculative | awk '{ print $3 }' | sed 's/\.//')
	free_mem=$((($free_blocks+speculative_blocks)*4096/1048576))
	# Calculate total memory
	phys=$(sysctl hw.memsize)
	total_mem=$(((${phys//[!0-9]/}/1073741824)))
	# Output system memory details
	echo "Mem Total: $total_mem GB"
	echo "Mem Free: $free_mem MB"

	# Output disk model
	hdd_model=$(diskutil info disk0 | grep "Media Name" | awk '{print $5}')
	echo "Disk Model: ${hdd_model}"

	# Calculate disk drive capacity & usage
	total_hdd=$(diskutil info disk0 | grep "Disk Size" | awk '{print $3,$4}')
	free_hdd=$(df -bg / | grep / | awk '{print $4}')
	# Output disk drive stats
	echo "Disk Size: ${total_hdd}"
	echo "Disk Free: ${free_hdd} GB"

	# Output type of storage medium in use for primary disk
	echo -n "Disk Type: "
	hdd_bool=$(diskutil info disk0 | grep "Solid State" | awk '{print $3}')
	if [ $hdd_bool == "No" ]; then
		echo "Rotational"
		hdd_rpm=$(system_profiler SPSerialATADataType | grep "Rotational Rate" | awk '{print $3}')
		# If drive is a rotational disk, output its RPM
		if [[ "${hdd_rpm}" ]]; then 
			echo "Disk Rotation Speed: ${hdd_rpm} RPM" 
		fi
	else
		echo "Solid State"
	fi

	# Check drive S.M.A.R.T. Health
	hdd_health=$(diskutil info disk0 | grep "SMART Status:" | awk '{print $3}')
	if [ $hdd_health == "Verified" ]; then
		echo "SMART Status: PASSED"
	else
		echo "SMART Status: FAILING"
	fi

	# Get system install date
	echo -n "System Installed: "
	ls -la /var/log/CDIS.custom | awk '{print $6, $7, $8}'

	# Calculate system uptime
	boot_sec=$(sysctl -n kern.boottime | awk '{print $4}')
	boot_sec=${boot_sec//[!0-9]/}
	boottime=$(($(date +%s)-boot_sec))
	# Output system uptime in hours, mins and days
	echo -n "Uptime: "
	display_time "${boottime}"

	# Get list of current users & remove duplicates
	pc_users=$(users | tr ' ' '\n' | sort | uniq | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
	# Output list of users logged into machine
	echo -n "Users Logged In: "
	if [[ ${pc_users} ]]; then
		echo ${pc_users}
	else
		echo "None"
	fi
}

# Checks which Unix varient we are running on
check_unix() {
	case "$OSTYPE" in
	solaris*) 
		os_type="Solaris"
		return 3
	;;
	darwin*)  
		os_type="OSX" 
		return 1
	;; 
	linux*)   
		os_type="Linux" 
		return 0
	;;
	bsd*)     
		os_type="BSD"
		return 3
	;;
	*)        
		os_type="unknown: $OSTYPE" 
		return 4
	;;
	esac
}

# Checks if OS is a tested to be compatible
# and runs most appropriate function
sys_info() {
	# Check Unix type
	check_unix
	# Select correct sys_info function
	case "$?" in
		0) linux_info ;;
		1) mac_info ;;
		*)
			echo "Warning: Untested Operating System (${os_type})!"
			read -r -p "This OS may not be compatible. Try anyway? [y/N] " response
			case "$response" in
			    [yY][eE][sS]|[yY]) 
					echo "Procceding..."
					linux_info
			    ;;
			    *)
					echo "Exiting..."
			    	exit
			    ;;
			esac
		;;
	esac
}

# Get system info for a remote machine
remote_info() {
	if [[ $1 ]]; then
		host=$1
	else
		# Get SSH target from user
		read -r -p "Target hostname or IP: " host
	fi
	# Run system info function on remote target
	typeset -f | ssh -To StrictHostKeyChecking=no "${host}" "$(cat);sys_info"
}

# Displays options menu
display_menu() {
	echo "1:  Lookup system info for current machine
2:  Lookup system info for remote machine
3:  Indentify Apple Product By Serial
	"

	read -r -p "Please choose an option: " response
	case "$response" in
		1)
			# Run system info check locally
			sys_info
		;;
		2)
			# Run system info check on remote machine
			remote_info
		;;
		3)
			# Request serial from user
			req_serial
			# Check serial for model name
			check_serial
		;;
		*)
			echo "Invalid option!"
		;;
	esac
}

# Proccess input arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -h|--help)
            print_help
            exit
        ;;
        -a|--about)
            print_info
            exit
        ;;
        -l|--local)
			interactive=false
			print_info
			sys_info
            shift # past argument
        ;;
        -s|--serial)
			serial=$2
			interactive=false
			print_info
			if [ ! "${serial}" ]; then
				echo "No serial entered!"
				req_serial
			fi
			check_serial
			shift # past argument
		;;
        -r|--remote)
			host=$2
			interactive=false
			print_info
			if [ ! "${host}" ]; then
				echo "No host entered!"
			fi
			remote_info "${host}"
			shift # past argument
        ;;
        *)
            # unknown option
            echo "Warning! Invalid argument: '${1}'"
        ;;
    esac
    shift # past argument or value
done

# Check if interactive mode disabled
if [ ! "${interactive}" = false ]; then
	# Display script info
	print_info
	# Run interactive menu
	display_menu
fi

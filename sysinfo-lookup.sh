#!/bin/bash

# Requests serial from user
req_serial() {
	echo -n "Please enter Apple serial number: "
	read serial
}

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
    echo "-s | --serial [serial no.]	: Provide serial (non-interactive mode)"
    echo "-d | --ondevice           	: Get info from current system"
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

# Gets system info about Linux & other non-Apple Unix systems
linux_info() {
	# Try sudo
	sudo echo &> /dev/null

	vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor)
	if [[ $vendor = *[!\ ]* ]]; then
		echo "System Manufacturer: ${vendor}" 
	else
		echo "MB Manufacturer: $(cat /sys/devices/virtual/dmi/id/board_vendor)"
	fi 

	product=$(cat /sys/devices/virtual/dmi/id/product_name)
	if [[ $product = *[!\ ]* ]]; then
		echo "Model: ${product}" 
	else
		echo "MB Model: $(cat /sys/devices/virtual/dmi/id/board_name)" 
	fi

	serial=$(sudo cat /sys/devices/virtual/dmi/id/product_serial)
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

	# Calculate disk drive capacity & usage
	total_hdd=$(diskutil info disk0 | grep "Disk Size" | awk '{print $3,$4}')
	free_hdd=$(df -bg / | grep / | awk '{print $4}')
	# Output disk drive stats
	echo "Disk Size: ${total_hdd}"
	echo "Disk Free: ${free_hdd} GB"

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

# Gets info of currently in-use device
on_device() {
	# Verify machine is running OSX
	if [[ "$OSTYPE" =~ darwin.* ]]; then
		mac_info
	else
		linux_info
	fi
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
        -d|--ondevice)
			interactive=false
			print_info
			on_device
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
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done

# Check if interactive mode disabled
if [ ! "${interactive}" = false ]; then
	print_info
	# Check if running on target machine
	read -r -p "Are we running on device in question? [y/N] " response
	case "$response" in
	    [yY][eE][sS]|[yY]) 
			on_device
		;;
	    *)
			req_serial
			check_serial
	    ;;
	esac
fi


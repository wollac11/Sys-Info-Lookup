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


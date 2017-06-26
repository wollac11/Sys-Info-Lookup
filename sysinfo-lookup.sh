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

# Gets system info about Linux & other non-Apple Unix systems
linux_info() {
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
}

# Gets serial of currently in-use device
on_device() {
	# Verify machine is running OSX
	if [[ "$OSTYPE" =~ darwin.* ]]; then
		# Obtain serial from system
		serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
		check_serial
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


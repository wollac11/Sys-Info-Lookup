#!/bin/bash

# Load defaults from config file
source "./sysinfo-lookup.conf"

# Intro header
print_info() {
	echo "-----------------------
----SYS INFO LOOKUP----
------Version 1.3------
--Charlie Callow 2017--
-----------------------
"
}

# Prints supported input options
print_help() {
    echo "-h | --help               	: See this options list"
    echo "-a | --about              	: View version info"
    echo "-u | --user [username]    	: Specify username for remote machine"
	echo "-p | --password [password]	: Specify password for remote machine (INSECURE!)"
    echo "-L | --log [file]         	: Log results to file"
    echo "-s | --serial [serial no.]	: Lookup model from Apple serial"
    echo "-l | --local              	: Get system info for current machine"
    echo "-r | --remote [host]  	 	: Get system info for remote machine"
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

# Verifies WMI-client is present
wmi_check () {
	# Check WMIC-client present
	if [ ! -f $wmic_bin ]; then
		echo "Missing WMIC-CLIENT (required for Windows hosts)"
		read -r -p "OK to download? [y/N] " response
		case "$response" in
		    [yY][eE][sS]|[yY]) 
				echo "Downloading WMIC-CLIENT..."
				wget -P ./DEPENDS/ https://github.com/R-Vision/wmi-client/raw/master/bin/wmic_ubuntu_x64 -q --show-progress
				echo "WMIC-CLIENT downloaded to ./DEPENDS/wmic_ubuntu_x64" 
				echo "Setting permissions..."
				chmod +x "${wmic_bin}" && echo
		    ;;
		    *)
				echo "Unable to procceed!"
				return 2
		    ;;
		esac
	fi
}

# Checks windows security status codes
check_win_security() {
	case $1 in
		# Windows Defender
		"393472") defstatus="Up to date" && rtstatus="Disabled" ;;
		"397584") defstatus="Out of date" && rtstatus="Enabled" ;;
		"397568") defstatus="Up to date" && rtstatus="Enabled" ;;
		# Other AV software
		"262144") defstatus="Up to date" && rtstatus="Disabled" ;;
		"266240") defstatus="Up to date" && rtstatus="Enabled" ;;
		"262160") defstatus="Out of date" && rtstatus="Disabled" ;;
		"266256") defstatus="Out of date" && rtstatus="Enabled" ;;
		"393216") defstatus="Up to date" && rtstatus="Disabled" ;;
		"393232") defstatus="Out of date" && rtstatus="Disabled" ;;
		"393488") defstatus="Out of date" && rtstatus="Disabled" ;;
		"397312") defstatus="Up to date" && rtstatus="Enabled" ;;
		"397328") defstatus="Out of date" && rtstatus="Enabled" ;;
		# Unknown status code
		*) defstatus="Unknown" && rtstatus="Unknown" ;;
	esac
}

# Gets system info about Linux & other non-Apple Unix systems
linux_info() {
	echo && echo "-- $(hostname): --" | tr /a-z/ /A-Z/
	# Try sudo
	sudo echo &> /dev/null

	echo "
         .888888:."
    echo -n "         88888.888.            	"

    # Get system manufacturer
	vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor)
	# Fallback to motherboard manufacturer if product manufacturer unavailable
	if [[ $vendor = *[!\ ]* ]]; then
		echo "System Manufacturer: ${vendor}" 
	else
		echo "MB Manufacturer: $(cat /sys/devices/virtual/dmi/id/board_vendor)"
	fi 

	echo -n "        .8888888888        	"

	# Get system product name
	product=$(cat /sys/devices/virtual/dmi/id/product_name)
	# Fallback to motherboard model if product model unavailable
	if [[ $product = *[!\ ]* ]]; then
		echo "Model: ${product}" 
	else
		echo "MB Model: $(cat /sys/devices/virtual/dmi/id/board_name)" 
	fi

	echo -n "        8' \`88' \`888       	"

	# Get system serial
	serial=$(sudo cat /sys/devices/virtual/dmi/id/product_serial)
	# Fallback to motherboard serial if product serial unavailable
	if [[ $serial = *[!\ ]* ]]; then
		echo "Serial: ${serial}" 
	else
		echo "MB Serial: $(sudo cat /sys/devices/virtual/dmi/id/board_serial)" 
	fi

	echo -n "        8 8 88 8 888       	"

	# Output OS distrubtion name & version
	echo "OS: $(lsb_release -a 2>/dev/null | grep "Description" | awk '{ for( i=2 ; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')"

	echo -n "        8:.,::,.:888       	"

	# Output system kernel version
	echo "Kernel: $(uname -mrs)"

	echo -n "       .8\`::::::'888       	"

	# Output CPU model and core/thread count
	cpu_model=$(grep -m 1 "model name" /proc/cpuinfo |  awk '{ for( i=4 ; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	cpu_count=$(cat /proc/cpuinfo | grep processor | wc -l)
	echo "CPU: ${cpu_model}x ${cpu_count}"

	echo -n "       88  \`::'  888       	"

	# Output GPU Model
	gpu_model=$(lspci | grep -i 'vga\|3d\|2d' | awk '{ for( i=5 ; i <=NF-2 ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	vram=$(($(grep -P -o -i "(?<=memory:).*(?=kbytes)" /var/log/Xorg.0.log)))
	echo -n "GPU: ${gpu_model}"
	if [ ! $vram == "0" ]; then
		echo "($((vram / 1024)) MB)"
	else
		echo
	fi

	echo -n "      .88        \`888.       	"

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

	echo -n "    .88'   .::.  .:8888.       	"

	echo "Mem Free: ${free_mem} MB"

	echo -n "    888.'   :'    \`'88:88.  	"

	# Output disk model
	hdd_model=$(sudo smartctl -i /dev/sda | grep Family | awk '{ for( i=3; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	echo "Disk Model: ${hdd_model}"

	echo -n "  .8888'    '        88:88. 	"

	# Calculate disk usage for common partitions
	free_root=$(df -BG / | grep / | awk '{print $4}')
	free_home=$(df -BG /home | grep / | awk '{print $4}')
	free_scratch=$(df -BG /scratch 2>/dev/null | grep / | awk '{print $4}')
	# Calculate disk capacity
	total_hdd=$(lsblk -b --output SIZE -n -d /dev/sda)
	total_hdd=$((${total_hdd}/1000000000))
	# Output disk stats
	echo "Disk Size: ${total_hdd} GB"

	echo -n " .8888'     .        88:888  	"

	echo -n "Disk Free: ${free_root//[!0-9]/} GB ROOT, ${free_home//[!0-9]/} GB HOME"

	# Output notification if no scratch partition found
	if [ $free_scratch ]; then
		echo ", ${free_scratch//[!0-9]/} GB SCRATCH"
	else
		echo "." && echo "           No scratch partition found."
	fi

	echo -n " \`88888     :        8:888'  	"

	# Output type of storage medium in use for primary disk
	echo -n "Disk Type: "
	hdd_bool=$(cat /sys/block/sda/queue/rotational)
	if [ $hdd_bool == "1" ]; then
		echo -n "Rotational"
		hdd_rpm=$(sudo hdparm -I /dev/sda | grep Rotation | awk '{print $5}')
		# If drive is a rotational disk, output its RPM
		if [[ "${hdd_rpm}" ]]; then 
			echo " (${hdd_rpm} RPM)"
		else
			echo
		fi
	else
		echo "Solid State"
	fi

	echo -n "  \`.:.88    .       .::888'  	"

	# Check drive S.M.A.R.T. Health
	hdd_health=$(sudo smartctl -H /dev/sda | grep "overall-health" | awk '{print $6}')
	echo "SMART Status: ${hdd_health}"

	echo -n " .:::::88   \`      .:::::::.  	"

	# Get system installation date
	echo -n "System Installed: "
	sudo tune2fs -l /dev/sda1 | grep created | awk '{print $5, $4, $7}'

	echo -n ".::::::.8         .:::::::::  	"

	# Calculate system uptime
	seconds=$(cat /proc/uptime | awk '{print $1}')
	seconds=${seconds%.*}
	# Output system uptime in hours, mins and days
	echo -n "Uptime: "
	echo $((seconds/86400))" days,"\
     $(date -d "1970-01-01 + $seconds seconds" "+%H hours, %M minutes.")

	echo -n ":::::::::..     .:::::::::'  	"

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

	echo " \`:::::::::88888:::::::'
      \`:::'       \`:'
	"

	echo "------------" && echo
}

mac_info() {
	echo && echo "-- $(hostname): --" | tr /a-z/ /A-Z/

	echo "
                       .8
                     .888
                    .8888'
                  .8888'              	Manufacturer: Apple Inc."
	echo -n "                  888'              	"

	# Obtain serial from system
	serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	# Get model from serial
	check_serial

	echo -n "                  8'              	"

	# Display serial
	echo "Serial: ${serial}"

	echo -n "      .88888888. .8888888888.    	"

	# Output OS version from system
	os_ver=$(sw_vers -productVersion)
	echo -n "OS: ${os_ver} "
	# Lookup & output marketing name for OS release
	curl -s http://support-sp.apple.com/sp/product?edid=${os_ver} | awk -v FS="(<configCode>|</configCode>)" '{print $2}'
	
	echo -n "   .888888888888888888888888888. 	"

	# Output system kernel version
	echo "Kernel: $(uname -mrs)"

	echo -n " .888888888888888888888888888888. 	"

	# Output CPU model & logical core count
	echo "CPU: $(sysctl -n machdep.cpu.brand_string) x $(sysctl -n hw.ncpu)" 

	echo -n ".&&&&&&&&&&&&&&&&&&&&&&&&&&&&&' 	"

	# Output GPU Model
	gpu=$(system_profiler SPDisplaysDataType | grep -m 1 Model | awk '{ for( i=3 ; i <=NF ; i++ ) { printf( "%s ", $i ) } ; print "" }')
	vram=$(system_profiler SPDisplaysDataType | grep -m 1 VRAM | awk '{print $3, $4}')
	echo "GPU: ${gpu} (${vram})"

	echo -n "&&&&&&&&&&&&&&&&&&&&&&&&&&&&'    	"

	# Calculate 'free' memory
	free_blocks=$(vm_stat | grep free | awk '{ print $3 }' | sed 's/\.//')
	speculative_blocks=$(vm_stat | grep speculative | awk '{ print $3 }' | sed 's/\.//')
	free_mem=$((($free_blocks+speculative_blocks)*4096/1048576))
	# Calculate total memory
	phys=$(sysctl hw.memsize)
	total_mem=$(((${phys//[!0-9]/}/1073741824)))
	# Output system memory details
	echo "Mem Total: $total_mem GB"

	echo -n "&&&&&&&&&&&&&&&&&&&&&&&&&&&'    	"

	echo "Mem Free: $free_mem MB"

	echo -n "@@@@@@@@@@@@@@@@@@@@@@@@@@:      	"


	# Output disk model
	hdd_model=$(diskutil info disk0 | grep "Media Name" | awk '{print $5}')
	echo "Disk Model: ${hdd_model}"

	echo -n "@@@@@@@@@@@@@@@@@@@@@@@@@@:      	"

	# Calculate disk drive capacity & usage
	total_hdd=$(diskutil info disk0 | grep 	-m 1 "Size" | awk '{print $3,$4}')
	free_hdd=$(df -bg / | grep / | awk '{print $4}')
	# Output disk drive stats
	echo "Disk Size: ${total_hdd}"

	echo -n "%%%%%%%%%%%%%%%%%%%%%%%%%%%.       	"

	echo "Disk Free: ${free_hdd} GB"

	echo -n "%%%%%%%%%%%%%%%%%%%%%%%%%%%%.       	"

	# Output type of storage medium in use for primary disk
	echo -n "Disk Type: "
	hdd_bool=$(diskutil info disk0 | grep "Solid State" | awk '{print $3}')
	if [ $hdd_bool == "No" ]; then
		echo -n "Rotational"
		hdd_rpm=$(system_profiler SPSerialATADataType | grep "Rotational Rate" | awk '{print $3}')
		# If drive is a rotational disk, output its RPM
		if [[ "${hdd_rpm}" ]]; then 
			echo " (${hdd_rpm} RPM)"
		else
			echo
		fi
	else
		echo "Solid State"
	fi

	echo -n "\`%%%%%%%%%%%%%%%%%%%%%%%%%%%%%.      	"

	# Check drive S.M.A.R.T. Health
	hdd_health=$(diskutil info disk0 | grep "SMART Status:" | awk '{print $3}')
	if [ $hdd_health == "Verified" ]; then
		echo "SMART Status: PASSED"
	else
		echo "SMART Status: FAILING"
	fi

	echo -n " \`0000000000000000000000000000000'  	"

	# Get system install date
	echo -n "System Installed: "
	ls -la /var/log/CDIS.custom | awk '{print $6, $7, $8}'

	echo -n "  \`00000000000000000000000000000'   	"

	# Calculate system uptime
	boot_sec=$(sysctl -n kern.boottime | awk '{print $4}')
	boot_sec=${boot_sec//[!0-9]/}
	boottime=$(($(date +%s)-boot_sec))
	# Output system uptime in hours, mins and days
	echo -n "Uptime: "
	display_time "${boottime}"

	echo -n "   \`000000000000000000000000000'   	"

	# Get list of current users & remove duplicates
	pc_users=$(users | tr ' ' '\n' | sort | uniq | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
	# Output list of users logged into machine
	echo -n "Users Logged In: "
	if [[ ${pc_users} ]]; then
		echo ${pc_users}
	else
		echo "None"
	fi

	echo "     \`#######################'
       \`###################'
         \`#######''######'
           \`\"\"\"\"'  \`\"\"\"'
	"

	echo "------------" && echo
}

# Gets system info about Windows systems (EXPERIMENTAL)
windows_info() {
	echo && echo "-- ${host}: --" | tr /a-z/ /A-Z/

	# Build arrays of computer info
	IFS='|' read -r -a os_sys_info <<< $(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT FreePhysicalMemory,Name,InstallDate,LastBootUpTime,LocalDateTime,Version FROM Win32_OperatingSystem" | tail -1)
	IFS='|' read -r -a comp_sys_info <<< $(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT TotalPhysicalMemory,Manufacturer,Model,Username FROM Win32_ComputerSystem" | tail -1)
	IFS='|' read -r -a cpu_info <<< $(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT Name,NumberOfLogicalProcessors from Win32_Processor" | tail -1)
	IFS='|' read -r -a disk_drive_info <<< $(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT Status,Model,Size FROM Win32_DiskDrive" | grep "PHYSICALDRIVE0")
	IFS='|' read -r -a video_card_info <<< $(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT Name,AdapterRAM from Win32_VideoController" | tail -1)

	# Get Serial no.
	serial_no=$(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT SerialNumber from Win32_Bios" | tail -1 | awk -F\| '{print $2}')

	# Get free disk space
	disk_free=$(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} "SELECT FreeSpace from Win32_LogicalDisk" | grep "C:" | awk -F\| '{print $2}')

	# Get status for each AV program into an array
	while IFS= read -r line ; do
	    av_info+=("${line}")
	done < <(${wmic_bin} -U "${win_domain}\\${user}" --password=${pass} //${host} --namespace='root\SecurityCenter2' "SELECT displayName,productState FROM AntiVirusProduct" | tail -n +3)

	# Iterate through each AV program
	for i in "${av_info[@]}"
	do
		# Split properties into seperate array items
		IFS='|' read -r -a av_status <<< $(echo "$i")
		# Combine to single array
		av_soft+=( "${av_status[@]}" )
	done

	# Check SMART Status
	if [ ${disk_drive_info[3]} == "OK" ]; then
		smart_stat="PASSED"
	else
		smart_stat="FAILING"
	fi

	# Check if any users logged in
	if [ ! ${comp_sys_info[4]} == "(null)" ]; then
			pc_users="${comp_sys_info[4]}"
		else
			pc_users="None"
	fi

	# Extact dates / times
	sys_started=$(sed -r 's#(.{4})(.{2})(.{2})(.{2})(.{2})#\1/\2/\3 \4:\5:#' <<< "${os_sys_info[2]%.*}")
	sys_now=$(sed -r 's#(.{4})(.{2})(.{2})(.{2})(.{2})#\1/\2/\3 \4:\5:#' <<< "${os_sys_info[3]%.*}")
	sys_installed=$(sed -r 's#(.{4})(.{2})(.{2})(.{2})(.{2})#\1/\2/\3 \4:\5:#' <<< "${os_sys_info[1]%.*}")
	# Convert to EPOCH
	sys_started=$(date -d "${sys_started}" "+%s")
	sys_now=$(date -d "${sys_now}" "+%s")
	# Calculate difference between current time and start time
	sys_up=$((sys_now - sys_started))
	# Convert to human readable date
	sys_installed=$(date -d "${sys_installed}" +"%d %b %Y")

	# Output results
	echo "
        ,.=:^!^!t3Z3z.,              	Manufacturer: ${comp_sys_info[0]}
       :tt:::tt333EE3                 	Model: ${comp_sys_info[1]}
       Et:::ztt33EEE  @Ee.,      ..,   	Serial: ${serial_no}
      ;tt:::tt333EE7 ;EEEEEEttttt33#  	OS: ${os_sys_info[4]}
     :Et:::zt333EEQ. SEEEEEttttt33QL   	Kernel: NT ${os_sys_info[7]}
     it::::tt333EEF @EEEEEEttttt33F   	CPU: ${cpu_info[1]} x ${cpu_info[2]}
    ;3=*^\`\`\`'*4EEV :EEEEEEttttt33@.	GPU: ${video_card_info[2]} ($((video_card_info[0] / 1048576)) MB)
    ,.=::::it=., \` @EEEEEEtttz33QF   	Mem Total: $(round ""${comp_sys_info[3]}"/1073741824" "0" ) GB
   ;::::::::zt33)   '4EEEtttji3P*     	Mem Free: $(( os_sys_info[0] / 1000 )) MB
  :t::::::::tt33.:Z3z..  \`\` ,..g.  	Disk Model: ${disk_drive_info[1]}
  i::::::::zt33F AEEEtttt::::ztF       	Disk Size: $(( disk_drive_info[2] / 1000000000 )) GB
 ;:::::::::t33V ;EEEttttt::::t3       	SMART Status: ${smart_stat}"
	# Interate through every installed AV program
	for i in ${!av_soft[@]}; do
		# Procceed for every third data item (AV status)
		if (( $(($((i+1)) % 3 )) == 0 )); then
			# Check AV status value
			check_win_security "${av_soft[${i}]}"
			# If not first AV program, add space before output
			if ! $fst_av ; then echo -n "it::::::::33EEF @EEEEEE:::::33F                    " ; fi
			if $fst_av ; then echo -n " E::::::::zt33L @EEEtttt::::z3F        	AV Status: " ; fi
			# Print AV status description
			echo "${av_soft[$((i-2))]} is ${rtstatus} & ${defstatus}"
			# Record an AV has been proccessed (subsequent are not the first)
			local fst_av=false
		fi
	done
	echo "{3=*^\`\`\`'*4E3) ;EEEtttt:::::tZ\`  	System Installed: ${sys_installed}
            \` :EEEEtttt::::z7        	Uptime: $(display_time "${sys_up}")
                'VEzjt:;;z>*\`         	Users Logged In: ${pc_users}"

	echo "------------" && echo

	# Clear AV lists
	unset av_info
	unset av_soft
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
					echo "Skipping..."
			    ;;
			esac
		;;
	esac
}

# Checks remote host connectivity and OS family (Windows / Unix)
check_target() {
	# Check host set
	if [[ "${host}" ]]; then
		# Host set, check connection
		echo "Checking connectivity to ${host}..."
		if ping -c 1 ${host} &> /dev/null
		then
			echo "Connection Success!"
			# Detect OS family by TTL
			tcp_ttl=$(ping -c 1 ${host} 2> /dev/null | grep "bytes from" | awk '{print $(NF-2)}')
			if (("${tcp_ttl//[!0-9.]/}" >= 117 && "${tcp_ttl//[!0-9.]/}" <= 137)); then
				# Windows-based system
				return 1 
			else
				# Unix-based system 
				return 0
			fi
		else
			# No connection
			return 2
		fi
	else
		# No host given
		return 3
	fi
}

# Gets remote info over ssh
info_ssh() {
	if [ ${pass} ]; then
		# Check for sshpass
		if hash sshpass 2>/dev/null; then
			sshpass -p ${pass} ssh -To StrictHostKeyChecking=no -l "${user}" "${host}"  "$(typeset -f); sys_info"
		else
			echo "ERROR: 'sshpass' required to supply unix password non-interactively but not installed."
		fi
	else
		ssh -To StrictHostKeyChecking=no -l "${user}" "${host}"  "$(typeset -f); sys_info"
	fi
}

# Get system info for a remote machine
remote_info() {
	if [[ $1 ]]; then
		host=$1
	else
		# Get SSH target from user
		read -r -p "Target hostname or IP: " host
	fi

	# Check remote connectivity and OS family
	check_target
	case "$?" in
		0)
			if [ ${log} ]; then		# Check if log set
				# Run system info function on remote target, redirect copy to log
				info_ssh 2>&1 | tee -a ${log}
			else
				# Run system info function on remote target, no log
				info_ssh
			fi
		;;
		1)
			echo "WARNING: ${host} appears to be running Windows"
			# Check we running on Linux
			check_unix
			if [ $? == "0" ]; then
				echo "Windows support is EXPERIMENTAL!"
				wmi_check # Check requisite WMI-client is present
				if [ ! $? == "2" ]; then # Continue if WMI-client check passed
					# Get password for Windows target
                    if [[ ! ${pass} ]]; then # If no password defined
						echo && read -s -r -p "Password for ${host}: " pass && echo
					fi

					if [ ${log} ]; then		# Check if log set
						# Run Windows sys info function, redirect copy to log
						windows_info 2>&1 | tee -a ${log}
					else
						# Run Windows sys info function, no log
						windows_info
					fi
				fi
			else
				echo "Currently Windows clients can only be checked from Linux hosts"
			fi
		;;
		3)
			# No hostname given
			echo "Cannot continue without a specified target."
		;;
		*)
			echo "Connection to ${host} Failed!"
		;;
	esac
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
			if [ ${log} ]; then		# Check if log set
				# Run system info check locally, redirect copy to log
				sys_info 2>&1 | tee -a ${log}
			else
				# Run system info check locally, no log
				sys_info
			fi
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

# Display script info
print_info

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
			if [ ${log} ]; then		# Check if log set
				# Run system info check locally, redirect copy to log
				sys_info 2>&1 | tee -a ${log}
			else
				# Run system info check locally, no log
				sys_info
			fi
        ;;
        -L|--log)
			# Check log filename given 
			if [[ ! "$2" ]] || [[ "$2" == -* ]]; then				
				echo "No log file specified!"
				echo "No log will be recorded."
			else
				log=$2
				# Check if log file exists with this name
				if [ -f $log ]; then
						echo "Log file "${log}" already exists!"
						echo "Exiting log file will be OVERWRITTEN."
						rm -f ${log} # Remove old log
				fi
				shift # past argument
			fi
			echo
        ;;
        -u|--user)
		# Check user has been specified
		if [[ ! "$2" ]] || [[ "$2" == -* ]]; then
			echo "No user specified, using default (${user})."
		else
			user=$2
			shift # past argument
		fi
		;;
		-p|--password)
		# Check password has been specified
		if [[ ! "$2" ]] || [[ "$2" == -* ]]; then
			echo "No password specified."
			echo "You will be prompted to enter one if/when required."
		else
			pass=$2
			shift # past argument
		fi
		;;
        -s|--serial)
			serial=$2
			interactive=false
			# Check serial number has been specified
			if [[ ! "${serial}" ]] || [[ "$2" == -* ]]; then
				echo "No serial entered!"
				req_serial
			fi
			check_serial
			shift # past argument
		;;
        -r|--remote)
			host=$2
			interactive=false
			# Check hostname has been specified
			if [[ ! "${host}" ]] || [[ "$2" == -* ]]; then
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
	# Run interactive menu
	display_menu
fi

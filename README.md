# Sys-Info-Lookup
*Forked from my own [Apple-Model-Lookup](https://github.com/wollac11/Apple-Model-Lookup/) script.*

Look up system information for a local or remote machine or check the model / marketing name of any Apple product by its serial number (excluding peripherals).

**Usage:**
Download and run script from BASH shell. Script can be used interactively or by supplying the appropriate input arguments.

- Interactive Mode: 
	Follow menu prompts to display system info for current or remote machine or to lookup model by Apple serial number.
- Non-interactive Mode: 
	Use the appropriate input arguments to get the desired result in a single step with zero or minimal further interaction.  
	These options are as follows:

	-h | --help               	: See this options list  
	-a | --about              	: View version info  
	-u | --user [username]    	: Specify username for remote machine  
	-p | --password [password]	: Specify password for remote machine (Potentially insecure!)  
	-L | --log [file]         	: Log results to file  
	-s | --serial [serial no.]	: Lookup model from Apple serial  
	-l | --local              	: Get system info for current machine  
	-r | --remote [host]  	 	: Get system info for remote machine  

**System Requirements:**

- A Unix-based operating system (such as Linux or MacOS)
- BASH Shell
- cURL
- WMIC (for Windows targets, auto-downloaded if missing)
- smartmontools (on Linux targets)
- WMI allowed by firewall (on Windows targets)

**Serial Number Lookup Compatibility:**

Known to work:  
- Macs including iMac, Macbook & Mac Pro lines  
- iOS devices including iPhone & iPad  
- Network devices (such as Airport Express)  

May work (not tested):  
- Apple Watch  
- Other devices with 11-12 character serial numbers  

Won't work:  
- Apple Mice  
- Apple Cinema Displays  
- Devices with serial numbers > 12 characters  
- Non-Apple devices


**Note:** This script will not run on Windows. A Windows/DOS version may be considered in the future.

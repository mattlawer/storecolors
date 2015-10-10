## storecolors
Get the average colors for AppStore top apps.

## Installation
	git clone https://github.com/mattlawer/storecolors.git
	cd storecolors
	make
	make install

## Usage
	Usage : storecolors [ -c <country_code> -l <list_size> -p ] -o output
		-c <country_code> : the country code to use (default: US)
		-p : search top paid (default: free)
		-l <list_size> : 1-200 (default: 200)
		-o <output_dir> : the output directory
	
	example:
		storecolors -c US -l 50
		will scan the 50 top free apps in US

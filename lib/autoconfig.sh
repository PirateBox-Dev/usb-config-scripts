#!/bin/sh

MODULE_LIST=""


#Default compare and set
auto_config_lookup_and_set(){
    local config=$1; shift
    local filename=$1; shift
    local current_status_file=$1; shift

     $DEBUG && echo "lookup_set: config              - $config"
     $DEBUG && echo "lookup_set: filename            - $filename"
     $DEBUG && echo "lookup_set: current_status_file - $current_status_file"

    if [ -f "$filename" ] ; then
        current_value=$( head -n 1 "$current_status_file" )
        new_value=$( head -n 1 "$filename" )

	$DEBUG && echo "Config file found"
	$DEBUG && echo "   tmp (current): '${current_value}'"
	$DEBUG && echo "   config : '${new_value}'"

        if [ "${current_value}"  != "${new_value}" ] ; then
            if test ! -z "${new_value}" ; then
                echo " $config - configuration is different, setting to new value"
                func_set_system_config_$config "$new_value" "$current_value"
                changed=1
             else
                echo "ERROR - $config , $filename , empty new value not allowed .'$new_value'"
                return 0
             fi
        fi
    fi

    return $changed
}

#Processes all modules.enabled
auto_config_process_all() {

	#### Global var
	changed=0
	uci_commit_needed="0"
	####

        for config in  $MODULE_LIST
        do
		echo "Working on $config"
                func_read_system_config_$config  $cfg_tmp_folder
                func_compare_and_set_$config
		#save new set value, which will be moved later
		func_read_system_config_$config  $cfg_tmp_folder
        done

	if [ "$changed" = "1" ] ; then
		echo "done some changes.."
		if [ "$uci_commit_needed" == "1" ] ; then
			 echo "doing uci commit" 
			uci commit
		fi
        fi
	return 0
}

_load_modules_() {
	local module_path=$1 ; shift


	local available_module_files=$(ls $cfg_modules)

	 $DEBUG  && echo "modules_folder $cfg_modules "
	 $DEBUG  && echo "ls result: $available_module_files"

	for module in $available_module_files
	do
		echo -n  "Loading module $module .."
		. $cfg_modules/$module
		echo "done"
	done

	echo "Available modules: $MODULE_LIST "

	return 0
}


_start_() {

	changed=0

	# check if $cfg_modules is available
	if [ ! -d $cfg_modules ] ; then
		echo "config module folder $cfg_modules does not exists"
		exit 1
	fi

	# load modules
	_load_modules_ || exit $?

	# check & create folder, if needed
        mkdir -p  $cfg_tmp_folder
        mkdir -p  $cfg_auto_folder


	# Run configuration
	auto_config_process_all

	# Transfer exported config values
	cp $cfg_tmp_folder/* $cfg_auto_folder

	
	if [ "$changed" == "1" ] ; then
		#If we changed something we deliver 0 as RC, because
		#we did our work successfully
		exit 0
	else
		#So, we haven't changed something, so, we inform with 
		#RC 1 as a hint
		exit 1
	fi
}	


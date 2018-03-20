#!/bin/bash

#获取当前脚本所在路径
function get_cur_script_location()
{
	pwd_dir=`pwd`
	location_dir=$(cd `dirname $0`; pwd)
	cd  $pwd_dir
	
	echo "$location_dir"
}


#import json_function.sh
. $(get_cur_script_location)/json_function.sh

json_file=oem.json

function main()
{
	stty erase '^H'
	read -p "member:" member leftpver
	
	local content=`cat $json_file`;
	
	local b_has=`has_member "$content" $member`
	if [ $b_has != "true" ];then
		echo "Find member [$member] failed";
		echo "Error: $b_has"
		exit;
	fi
	
	local v_type=`get_value_type "$content" $member`
	echo "Key: $member, type: $v_type"
	
	local v_length=`get_length "$content" $member`
	echo "Key: $member, length: $v_length"
	
	local v=`get_value "$content" $member`
	echo "Key: $member, value: $v"
	
	local keys=`get_keys "$v"`
	local keys_length=`get_length "$keys"`
	local keys_0=`get_value "$keys" [0]`
	echo "keys of $member: $keys, keys_length: $keys_length"
	echo "keys[0]: $keys_0"
}


main

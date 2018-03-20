#!/bin/bash

if [ "$json_function" ]; then
        return
fi

export json_function="json_function.sh"

#获取当前脚本所在路径
function get_cur_script_location()
{
	local pwd_dir=`pwd`
	local location_dir=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)
	cd  $pwd_dir
	
	echo "$location_dir"
}


jq_bin=$(get_cur_script_location)/jq-linux64

#获取json的值类型
#参数：
#	json_value_src
#	json_key_path
#返回值 value_type
function get_value_type()
{
	local json_value_src=$1
	local json_key_path=$2
	
	local jq_cmd=$jq_bin
	jq_cmd+=" "".$json_key_path|type"
	
	local value_type=`echo $json_value_src | $jq_cmd`
	
	echo $value_type;
}

#检查是否含有该成员
#参数：
#	json_value_src
#	json_member
#返回值 true/false
function has_member() 
{	
	#json的value字符串
	local json_value_src=$1
	
	#待确认的成员
	local json_member=$2
	
	local jq_cmd=$jq_bin
	jq_cmd+=" ""has(\"$json_member\")"
	
	local b_has=`echo $json_value_src | $jq_cmd`
	
	echo $b_has
}

#获取json值
#参数：
#	json_value_src
#	json_key
#返回值 key对应的值
function get_value()
{
	#json value字符串
	local json_value_src=$1
	
	#获取value的key
	local json_key=$2
	
	local jq_cmd=$jq_bin
	jq_cmd+=" "".$json_key"
	
	local json_value=`echo $json_value_src | $jq_cmd`
	
	echo $json_value
}

#获取json key对应值的长度
#参数：
#	json_value_src
#	json_key
#返回值 长度
function get_length()
{
	#json value字符串
	local json_value_src=$1
	
	#指定的key
	local json_key=$2
	
	local jq_cmd=$jq_bin
	jq_cmd+=" "".$json_key|length"
	
	local length=`echo $json_value_src | $jq_cmd`
	
	echo $length
}

#获取json 字符串中的所有key
#参数：
#	json_value_src
#返回值：key的json数组
function get_keys()
{
	#json_value
	local json_value_src=$1
	
	local jq_cmd=$jq_bin
	jq_cmd+=" ""keys"
	
	local keys_array=`echo $json_value_src | $jq_cmd`
	
	echo $keys_array
}

#检查是否是有效的json
#参数：
#   json_value_src
#返回值： true/false
function check_json()
{
    #json的value字符串
    local json_value_src=$1
    
    local jq_cmd=$jq_bin
    jq_cmd+=" ""."
    
    echo $json_value_src | $jq_cmd 2>&1 >>/dev/null

    local ret_code=$?
    
    local ret="false"

    if [ $ret_code -eq 0 ];then
        ret="true"
    fi  
    
    echo "$ret"
}
#!/bin/bash

if [ "$log_module" ]; then
        return
fi

export log_module="log.sh"

TRUE=/bin/true
FALSE=/bin/false

# 日志目录
log_file=""
# 日志文件大小(byte)
log_max_size=2000000

# 如果执行过程中有错误信息均输出到日志文件中
if [ -d $(dirname $log_file) ];then
	exec 2>>$log_file
else
	mkdir -p $(dirname $log_file)
fi

# 日志类型
log_levels=("TRACE" "INFO" "WARNING" "ERROR" "CRITICAL")

# 检查日志类型是否合法
function check_level()
{
	local lv=$1
	local ret="false"
	for inner_lv in ${log_levels[*]}
	do
		if [[ $lv == $inner_lv ]];then
			ret="true"
			break
		fi
	done
	
	echo $ret
}

# shell变量类型
var_type=("integer" "number" "char" "string")

# 检查并获取变量类型
function check_type()
{
	local var="$1"
	
	printf "%d" "$var" &>/dev/null && echo "integer" && return
	printf "%d" "$(echo $var|sed 's/^[+-]\?0\+//')" &>/dev/null && echo "integer" && return
	
	printf "%f" "$var" &>/dev/null && echo "number" && return
	[ ${#var} -eq 1 ] && echo  "char" && return

	echo "string"
}

# 设置日志目录
function set_log_file()
{
	local path=$1
	local checked_type=$(check_type $path)
	if [[ $checked_type != "string" ]]
	then
		$FALSE
		return $?
	fi
	
	local log_dir=$(dirname $path)
	if [[ $log_dir == "" ]]
	then
		$FALSE
		return $?
	fi
	
	# 创建日志目录
	mkdir -p $log_dir
	
	# 设置全局变量
	log_file=$path
	
	exec 2>>$log_file
}

# 日志
# 参数：
#		日志类型
#		日志内容
function s_log()
{
	# 参数个数
	local parm_num=2
	local input_parm_num=$#
	#检查参数个数是否正确
	if [ $parm_num -gt $input_parm_num ]
	then
		echo "Error: Invalid parameter number: $input_parm_num, $parm_num is expected!" 1>&2
		return;
	fi
	
	# 顺序定义参数类型
	local param_type=("string" "")
	
	# 顺序检查参数类型
	for ((param_index=1;param_index<=$parm_num;param_index++))
	{
		local inner_type=${param_type[$param_index-1]}
		if [[ $inner_type != "" ]];then
			local checked_type=$(check_type ${!param_index})
			if [[ $checked_type != $inner_type ]];then
				echo "Error: #$i is $checked_type, but $inner_type is expected!" 1>&2
				return;
			fi
		fi
	}
	
	# 检查目标日志文件是否存在
	if [ ! -e "$log_file" ]
	then
		touch $log_file
	fi
	
	# 当前时间
	local cur_time=$(date +"%Y%m%d%H%M%S")
	
	# 当前文件大小
	local cur_file_size=$(stat -c %s $log_file | tr -d '\n');
	if [ $log_max_size -lt $cur_file_size ]
	then
		mv $log_file ${log_file}.$cur_time
		touch $log_file;
	fi
	
	# 获取调用方信息
	local log_caller_info=($(caller 0))
	
	local log_type=$1
	local log_content=$2
	local call_file_no=${log_caller_info[0]}
	local call_file_name=$(cd $(dirname ${log_caller_info[2]}) && pwd)/$(basename ${log_caller_info[2]})
	local call_function=${log_caller_info[1]}
	
	# 检查日志级别是否合法
	if [ $(check_level $log_type) != "true" ];then
		echo "Error: Invalid log type [$log_type]. It should be like those below:" 1>&2
		for ((level_index=0;level_index<${#log_levels[@]};level_index++))
		{
			echo -e "\t${log_levels[$level_index]}" 1>&2
		}
		return;
	fi
	
	#写入文件
	echo "[$cur_time] [$log_type] [$call_file_name:$call_file_no:$call_function]: $log_content" >> $log_file
}
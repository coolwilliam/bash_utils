#!/bin/bash

##
#	设置策略路由
#	参数：
#		设备和IP数组（dev1 ip1 dev2 ip2 ...）
#		网段数组(net1 net2)
#		管理口设备 dev
#		管理口网关 gw
#		启动拉流标识 flag_up_stream
##


#标识范围
flag_begin="#ip_route_begin"
flag_end="#ip_route_end"

table_file=/etc/iproute2/rt_tables

table_no_base=100

#临时导出环境变量
export PATH=${PATH}:/sbin

ip_route_sh_dir=$(cd $(dirname "${BASH_SOURCE[0]}"); pwd)

# 导入log模块
. $ip_route_sh_dir/log.sh

ip_route_log_path=/home/work/streamMedia/var/ip_route/ip_route.log
mkdir -p $(dirname $ip_route_log_path)

set_log_file $ip_route_log_path

function route_rule_set()
{
	local device_array=($1)
	#local net_array=($2)
	local manage_dev=$2
	local manage_gw=$3
	local up_stream_flag=$4
	
	local DEF_UP_STREAM="upStream"
	
	# 清除当前策略路由表
	local rt_tables=($(ip ru | awk '{print $5" "$3}' | xargs))
	local array_num=${#rt_tables[@]}
	s_log "TRACE" "Array count: $array_num"
	s_log "TRACE" "Table: ${rt_tables[*]}"
	for ((tbl_index=0;tbl_index<$array_num;tbl_index=tbl_index+2))
	{
		local tbl=${rt_tables[$tbl_index]}
		local net=${rt_tables[$tbl_index+1]}
		s_log "TRACE" "Table[$tbl_index] $tbl"
		if [ $tbl == 0 -o $tbl == 'unspec' -o $tbl == 255 -o $tbl == 'local' -o $tbl == 254 -o $tbl == 'main' -o $tbl == 253 -o $tbl == 'default' ];then
			continue
		fi
		
		#删除规则
		ip rule del from ${net}/32 table $tbl
		if [ $? != 0 ];then
			s_log "ERROR" "Delete rule from $tbl failed!"
		fi
		
		#清空策略路由表
		ip route flush table $tbl
		if [ $? != 0 ];then
			s_log "ERROR" "Flush table $tbl failed!"
		fi
	}
	
	#替换rt_table中指定区域的内容
	local rt_tables=();
	#清除自定义表文件定义
	sed -i "/^$flag_begin/,/$flag_begin$/d" $table_file
	local content="$flag_begin"
	local content+="\n"
	local table_no=$table_no_base
	local table_count=${#device_array[@]}
	echo "Dev count $table_count"
	local devs_array=()
	for ((dev_index=0;dev_index<$table_count;dev_index=dev_index+2))
	{
		local tbl_name=tbl_$table_no
		content+=$table_no
		content+=" "$tbl_name
		content+="\n"
		rt_tables=(${rt_tables[@]} $tbl_name)
		devs_array=(${devs_array[@]} ${device_array[$dev_index]})
		let table_no++
	}
	content+="$flag_end"
	
	echo -e "$content" >>$table_file
	
	#清除所选设备的静态路由
	clear_static_route "${devs_array[*]}"
	
	#清除0.0.0.0段的静态路由
	local route_default_pair_array=($(route -n | grep ^0.0.0.0 | awk '{print $1" "$2" "$8}' | xargs))
	local default_count=${#route_default_pair_array[@]}
	for ((default_index=0;default_index<$default_count;default_index=default_index+3))
	{
		local net=$(change_ip_to_range ${route_default_pair_array[$default_index]})
		local gw=${route_default_pair_array[$default_index+1]}
		local dev=${route_default_pair_array[$default_index+2]}
		route del -net $net gw $gw dev $dev
		if [ $? != 0 ];then
			route del -net $net dev $dev
		fi
	}
	
	local dev_index=0
	for ((device_index=0;device_index<$table_count;device_index=device_index+2))
	{
		#为每个表添加默认路由
		local tbl=${rt_tables[$dev_index]}
		local dev=${device_array[$device_index]}
		local dev_ip=${device_array[$device_index+1]}
		
		#只设置一个网段
		route add -net 0.0.0.0/0 dev $dev
		ip route del to 0.0.0.0/0 dev $dev table $tbl
		ip route add to 0.0.0.0/0 dev $dev table $tbl
		
		#添加路由规则
		ip rule add from $dev_ip/32 table $tbl
		
		let dev_index++
	}
	
	#清除缓存
	ip route flush cache
	
	#设置默认管理口路由
	if [[ "" = $manage_gw ]];then
		# 如果没有网关
		route add -net 0.0.0.0/0 dev $manage_dev
	else
		route add -net 0.0.0.0/0 gw $manage_gw dev $manage_dev
	fi

	local http_path="http://127.0.0.1"
	# 是否启动拉流
	if [[ $DEF_UP_STREAM = $up_stream_flag ]];then
		curl -sL "$http_path/upIptvStream.chk"
	fi
}


#清除给定的设备的静态路由
function clear_static_route()
{
	local dev_array=$1
	
	local devs="";
	local count=1;
	for dev in ${dev_array[*]}; do
		if [[ $count > 1 ]];then
			devs=$devs"|"$dev
		else
			devs=$dev
		fi
		let count++
	done

	local route_pair_array=($(route -n | grep -Ew "$devs" | awk '{print $1" "$2" "$8}' | xargs))
	local route_count=${#route_pair_array[@]}
	for ((route_index=0;route_index<$route_count;route_index=route_index+3))
	{
		local net=$(change_ip_to_range ${route_pair_array[$route_index]})
		local gw=${route_pair_array[$route_index+1]}
		local dev=${route_pair_array[$route_index+2]}
		route del -net $net gw $gw dev $dev
		if [ $? != 0 ];then
			route del -net $net dev $dev
		fi
	}
}

#将IP转换成IP段表示
function change_ip_to_range()
{
	local ip=$1
	local mask=0
	local match_str=".0"
	local sub_len=0
	local tmp_str=$ip
	local max_count=4
	local match_count=0
	
	for ((dot_index=0;dot_index<$max_count;dot_index++))
	{
		#反向查找
		local sub_str=${tmp_str%$match_str}
		local sub_len=${#sub_str}
		local tmp_len=${#tmp_str}
		if [ $sub_len = ${#tmp_str} ];then
			if [ $tmp_str = "0" ];then
				let match_count++
			else
				break
			fi
		else
			
			local del_len=$(( $tmp_len - $sub_len ))
			if [[ $del_len != ${#match_str} ]];then
				break;
			else
				let match_count++
				tmp_str=$sub_str
			fi
		fi
	}
	
	local mul_num=$(( $max_count - $match_count ))
	
	echo $ip/$(( 8 * $mul_num ))
}

#设置默认路由
function set_default_route()
{
	local manage_dev=$3
	local manage_gw=$4
	
	#设置默认管理口路由
	local route_default_pair_array=($(route -n | grep ^0.0.0.0 | awk '{print $1" "$2" "$8}' | xargs))
	local default_count=${#route_default_pair_array[@]}
	for ((default_index=0;default_index<$default_count;default_index=default_index+3))
	{
		local net=$(change_ip_to_range ${route_default_pair_array[$default_index]})
		local gw=${route_default_pair_array[$default_index+1]}
		local dev=${route_default_pair_array[$default_index+2]}
		route del -net $net gw $gw dev $dev
	}
	
	if [[ "" = $manage_gw ]];then
		# 如果没有网关
		route add -net 0.0.0.0/0 dev $manage_dev
	else
		route add -net 0.0.0.0/0 gw $manage_gw dev $manage_dev
	fi
}

args=()
for ((arg_index=1;arg_index<=$#;arg_index++));do
	args[${arg_index}]="${!arg_index}"
done

route_rule_set "${args[@]}"
#只重新设置默认路由
#set_default_route "${args[@]}"

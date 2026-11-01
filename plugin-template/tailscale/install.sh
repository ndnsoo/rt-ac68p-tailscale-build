#!/bin/sh
source /jffs/softcenter/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
DIR=$(cd $(dirname $0); pwd)
MODEL=$(nvram get productid)
module=${DIR##*/}

platform_test(){
	local LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
	local MARCH=$(cat /tmp/${module}/.arch)
	local LARCH=$(dbus get softcenter_arch)
	if [ "$MARCH" == "$LARCH" ];then
		if [ "$MARCH" == "arm" -a "${LINUX_VER}" == "26" ];then
			echo_date 机型："${MODEL} 为 ARM/Linux 2.6 SWRT 兼容模式，继续安装并在安装后实机验证 TUN/转发能力。"
		else
			echo_date 机型："${MODEL} 符合安装要求，开始安装插件！"
		fi
	else
		echo_date 机型："${MODEL} 架构为$LARCH，插件架构为$MARCH，无法安装插件！"
		exit_install 1
	fi
}

set_skin(){
	local UI_TYPE=ASUSWRT
	local SC_SKIN=$(nvram get sc_skin)
	local SWRT_SKIN=$(nvram get swrt_skin)
	local TS_FLAG=$(grep -o "2ED9C3" /www/css/difference.css 2>/dev/null|head -n1)
	local ROG_FLAG=$(cat /www/form_style.css|grep -A1 ".tab_NW:hover{"|grep "background"|grep -o "2071044")
	local TUF_FLAG=$(cat /www/form_style.css|grep -A1 ".tab_NW:hover{"|grep "background"|grep -o "D0982C")
	if [ -n "${SWRT_SKIN}" ];then
		if [ "ts" == "${SWRT_SKIN}" ];then
			UI_TYPE="TS"
		elif [ "rog" == "${SWRT_SKIN}" ];then
			UI_TYPE="ROG"
		elif [ "tuf" == "${SWRT_SKIN}" ];then
			UI_TYPE="TUF"
		elif [ "swrt" == "${SWRT_SKIN}" ];then
			UI_TYPE="SWRT"
		fi
	elif [ -n "${TS_FLAG}" ];then
		UI_TYPE="TS"
	elif [ -n "${ROG_FLAG}" ];then
		UI_TYPE="ROG"
	elif [ -n "${TUF_FLAG}" ];then
		UI_TYPE="TUF"
	fi
	if [ -z "${SC_SKIN}" -o "${SC_SKIN}" != "${UI_TYPE}" ];then
		nvram set sc_skin="${UI_TYPE}"
		nvram commit
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/${module}* >/dev/null 2>&1
			exit 0
			;;
	esac
}

get_model(){
	local ODMPID=$(nvram get odmpid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	fi
}

install_now(){
	# default value
	local TITLE="Tailscale"
	local DESCR="基于wiregurad协议的零配置内网穿透安全组网工具！"
	local PLVER=$(cat ${DIR}/version)

	# stop before install
	if [ "$(dbus get tailscale_enable)" == "1" -a -f "/jffs/softcenter/scripts/tailscale_config.sh" ];then
		echo_date "安装前先关闭插件..."
		/jffs/softcenter/scripts/tailscale_config.sh stop
	fi

	# remove before install
	rm -rf /jffs/softcenter/bin/tailscale* >/dev/null 2>&1
	rm -rf /jffs/softcenter/res/icon-tailscale.png >/dev/null 2>&1
	rm -rf /jffs/softcenter/res/tailscale*.json >/dev/null 2>&1
	rm -rf /jffs/softcenter/scripts/tailscale_* >/dev/null 2>&1
	rm -rf /jffs/softcenter/scripts/uninstall_tailscale.sh >/dev/null 2>&1
	rm -rf /jffs/softcenter/webs/Module_tailscale.asp >/dev/null 2>&1
	find /jffs/softcenter/init.d -name "*tailscale*" | xargs rm -rf	

	# install file
	echo_date "安装插件相关文件..."
	cd /tmp

	# v12r2 package-selected storage. USB variants check USB only; dual variants check JFFS.
	local USBROOT=/tmp/mnt/ROUTERUSB
	local USBTS=${USBROOT}/tailscale
	local SWAPFILE=${USBROOT}/tailscale-swapfile
	if [ -f /tmp/${module}/bin/.usb_only ]; then
		[ -d "$USBROOT" ] && mount | grep -q " $USBROOT type ext4 " || { echo_date "未检测到EXT4 ROUTERUSB，停止安装！"; exit_install 1; }
		[ -f "$SWAPFILE" ] || { echo_date "未检测到U盘Swap文件，停止安装！"; exit_install 1; }
		grep -q "$SWAPFILE" /proc/swaps || /sbin/swapon "$SWAPFILE" 2>/dev/null || exit_install 1
		local USBFREE=$(df -k "$USBROOT" | awk 'NR==2 {print $4}')
		local CORE_KB=$(du -sk /tmp/${module}/bin 2>/dev/null | awk '{print $1}')
		local USBNEED=$((CORE_KB + 65536))
		[ "$USBNEED" -ge 100000 ] || USBNEED=100000
		echo_date "U盘可用空间：${USBFREE}KB，本安装包最低需要：${USBNEED}KB。"
		[ -n "$USBFREE" ] && [ "$USBFREE" -ge "$USBNEED" ] || { echo_date "U盘可用空间不足，停止安装！"; exit_install 1; }
		mkdir -p "$USBTS/bin" "$USBTS/state" "$USBTS/logs" "$USBTS/backups"
		BACKUP_DIR="$USBTS/backups/pre-v12r2-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BACKUP_DIR"
		[ -x "$USBTS/bin/tailscale" ] && cp -Lpf "$USBTS/bin/tailscale" "$BACKUP_DIR/tailscale" 2>/dev/null
		[ -x "$USBTS/bin/tailscaled" ] && cp -Lpf "$USBTS/bin/tailscaled" "$BACKUP_DIR/tailscaled" 2>/dev/null
		rm -f "$USBTS/bin/tailscale" "$USBTS/bin/tailscaled" "$USBTS/bin/tailscale_combo"
		if [ -f /tmp/${module}/bin/.combo ]; then cp -f /tmp/${module}/bin/tailscale_combo "$USBTS/bin/tailscale_combo" || exit_install 1; chmod 755 "$USBTS/bin/tailscale_combo"; ln -sf "$USBTS/bin/tailscale_combo" "$USBTS/bin/tailscale"; ln -sf "$USBTS/bin/tailscale_combo" "$USBTS/bin/tailscaled"; else cp -f /tmp/${module}/bin/tailscale "$USBTS/bin/tailscale" || exit_install 1; cp -f /tmp/${module}/bin/tailscaled "$USBTS/bin/tailscaled" || exit_install 1; chmod 755 "$USBTS/bin/tailscale" "$USBTS/bin/tailscaled"; fi
		rm -f /jffs/softcenter/bin/tailscale /jffs/softcenter/bin/tailscaled
		ln -sf "$USBTS/bin/tailscale" /jffs/softcenter/bin/tailscale
		ln -sf "$USBTS/bin/tailscaled" /jffs/softcenter/bin/tailscaled
		touch /jffs/softcenter/configs/tailscale_usb_only
	else
		local JCORE=/jffs/softcenter/tailscale-core; local JSTATE=/jffs/softcenter/etc/tailscale
		local JFREE=$(df -k /jffs | awk 'NR==2 {print $4}')
		[ -n "$JFREE" ] && [ "$JFREE" -ge 32000 ] || { echo_date "JFFS可用空间不足32MB，停止安装！"; exit_install 1; }
		mkdir -p "$JCORE" "$JSTATE"
		if mount | grep -q " $USBROOT type ext4 "; then mkdir -p "$USBTS/bin" "$USBTS/state" "$USBTS/logs" "$USBTS/backups"; [ -f "$USBTS/state/tailscaled.state" ] && [ ! -f "$JSTATE/tailscaled.state" ] && cp -pf "$USBTS/state/tailscaled.state" "$JSTATE/tailscaled.state"; fi
		rm -f "$JCORE/tailscale" "$JCORE/tailscaled" "$JCORE/tailscale_combo"
		if [ -f /tmp/${module}/bin/.combo ]; then cp -f /tmp/${module}/bin/tailscale_combo "$JCORE/tailscale_combo" || exit_install 1; chmod 755 "$JCORE/tailscale_combo"; ln -sf "$JCORE/tailscale_combo" "$JCORE/tailscale"; ln -sf "$JCORE/tailscale_combo" "$JCORE/tailscaled"; else cp -f /tmp/${module}/bin/tailscale "$JCORE/tailscale" || exit_install 1; cp -f /tmp/${module}/bin/tailscaled "$JCORE/tailscaled" || exit_install 1; chmod 755 "$JCORE/tailscale" "$JCORE/tailscaled"; fi
		rm -f /jffs/softcenter/configs/tailscale_usb_only
	fi

	cp -rf /tmp/${module}/res/* /jffs/softcenter/res/
	cp -rf /tmp/${module}/scripts/* /jffs/softcenter/scripts/
	cp -rf /tmp/${module}/webs/* /jffs/softcenter/webs/
	cp -rf /tmp/${module}/uninstall.sh /jffs/softcenter/scripts/uninstall_${module}.sh
	[ ! -L "/jffs/softcenter/init.d/S96tailscale.sh" ] && ln -sf /jffs/softcenter/scripts/tailscale_config.sh /jffs/softcenter/init.d/S96tailscale.sh
	[ ! -L "/jffs/softcenter/init.d/N96tailscale.sh" ] && ln -sf /jffs/softcenter/scripts/tailscale_config.sh /jffs/softcenter/init.d/N96tailscale.sh
	# Permissions
	chmod 755 /jffs/softcenter/bin/tailscale* >/dev/null 2>&1
	chmod 755 /jffs/softcenter/scripts/tailscale*.sh >/dev/null 2>&1
	/jffs/softcenter/scripts/tailscale_storage.sh select >/dev/null 2>&1 || true
	/jffs/softcenter/scripts/tailscale_bootstrap.sh || exit_install 1

	# intall different UI
	set_skin

	# set default value, incase in upgrade, newer script can't get latest key-value from web
	if [ -z "$(dbus get tailscale_accept_routes)" ];then
		dbus set tailscale_accept_routes="0"
	fi

	if [ -z "$(dbus get tailscale_advertise_routes)" ];then
		dbus set tailscale_advertise_routes="0"
	fi

	if [ -z "$(dbus get tailscale_exit_node)" ];then
		dbus set tailscale_exit_node="0"
	fi
	if [ -z "$(dbus get tailscale_auto_update)" ];then
		dbus set tailscale_auto_update="0"
	fi
	dbus set tailscale_auto_update="0"
	dbus set tailscale_usb_root="/tmp/mnt/ROUTERUSB/tailscale"
	dbus set tailscale_core_version="1.104.4"
	if [ -z "$(dbus get tailscale_login_server)" ];then
		dbus set tailscale_login_server="https://bb.776699.xyz"
	fi
	if [ -z "$(dbus get tailscale_hostname)" ];then
		dbus set tailscale_hostname="home-router-ac68u"
	fi
	
	# dbus value
	echo_date "设置插件默认参数..."
	dbus set ${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_install="1"
	dbus set softcenter_module_${module}_name="${module}"
	dbus set softcenter_module_${module}_title="${TITLE}"
	dbus set softcenter_module_${module}_description="${DESCR}"

	# start after install
	if [ "$(dbus get tailscale_enable)" == "1" -a -f "/jffs/softcenter/scripts/tailscale_config.sh" ];then
		echo_date "重新开启插件..."
		/jffs/softcenter/scripts/tailscale_config.sh start
	fi

	# finish
	echo_date "${TITLE}插件安装完毕！"
	exit_install
}

install(){
	get_model
	platform_test
	install_now
}

install


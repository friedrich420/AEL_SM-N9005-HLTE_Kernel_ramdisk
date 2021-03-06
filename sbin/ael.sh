#!/sbin/busybox sh

BB=/sbin/busybox

# protect init from oom
echo "-1000" > /proc/1/oom_score_adj;

PIDOFINIT=$(pgrep -f "/sbin/ext/ael.sh");
for i in $PIDOFINIT; do
	echo "-600" > /proc/"$i"/oom_score_adj;
done;

OPEN_RW()
{
        $BB mount -o remount,rw /;
        $BB mount -o remount,rw /system;
}
OPEN_RW;

# Boot with CFQ I/O Gov
$BB echo "cfq" > /sys/block/mmcblk0/queue/scheduler;

# create init.d folder if missing
if [ ! -d /system/etc/init.d ]; then
	mkdir -p /system/etc/init.d/
	$BB chmod 755 /system/etc/init.d/;
fi;

	if [ ! -d /data/init.d_bkp ]; then
		$BB mkdir /data/init.d_bkp;
	fi;
	$BB mv /system/etc/init.d/* /data/init.d_bkp/;

	# run ROM scripts
	if [ -e /system/etc/init.qcom.post_boot.sh ]; then
		 /system/bin/sh /system/etc/init.qcom.post_boot.sh
	else
		$BB echo "No ROM Boot script detected"
	fi;

	$BB mv /data/init.d_bkp/* /system/etc/init.d/

sleep 5;
OPEN_RW;

# some nice thing for dev
if [ ! -e /cpufreq ]; then
	$BB ln -s /sys/devices/system/cpu/cpu0/cpufreq /cpufreq;
	$BB ln -s /sys/devices/system/cpu/cpufreq/ /cpugov;
	$BB ln -s /sys/module/msm_thermal/parameters/ /cputemp;
fi;

# cleaning
$BB rm -rf /cache/lost+found/* 2> /dev/null;
$BB rm -rf /data/lost+found/* 2> /dev/null;
$BB rm -rf /data/tombstones/* 2> /dev/null;

CRITICAL_PERM_FIX()
{
	# critical Permissions fix
	$BB chown -R system:system /data/anr;
	$BB chown -R root:root /tmp;
	$BB chown -R root:root /res;
	$BB chown -R root:root /sbin;
	$BB chown -R root:root /lib;
	$BB chmod -R 777 /tmp/;
	$BB chmod -R 775 /res/;
	$BB chmod -R 06755 /sbin/ext/;
	$BB chmod -R 0777 /data/anr/;
	$BB chmod -R 0400 /data/tombstones;
	$BB chmod 06755 /sbin/busybox
}
CRITICAL_PERM_FIX;

# oom and mem perm fix
$BB chmod 666 /sys/module/lowmemorykiller/parameters/cost;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/adj;
$BB chmod 666 /sys/module/lowmemorykiller/parameters/minfree

# make sure we own the device nodes
$BB chown system /sys/devices/system/cpu/cpu0/cpufreq/*
$BB chown system /sys/devices/system/cpu/cpu1/online
$BB chown system /sys/devices/system/cpu/cpu2/online
$BB chown system /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
$BB chmod 666 /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq
$BB chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/stats/*
$BB chmod 666 /sys/devices/system/cpu/cpu1/online
$BB chmod 666 /sys/devices/system/cpu/cpu2/online
$BB chmod 666 /sys/devices/system/cpu/cpu3/online
$BB chmod 666 /sys/module/msm_thermal/parameters/*
$BB chmod 666 /sys/module/msm_thermal/core_control/enabled
$BB chmod 666 /sys/class/kgsl/kgsl-3d0/max_gpuclk
$BB chmod 666 /sys/devices/platform/kgsl-3d0/kgsl/kgsl-3d0/pwrscale/trustzone/governor

$BB chown -R root:root /data/property;
$BB chmod -R 0700 /data/property

# set ondemand GPU governor as default
echo "ondemand" > /sys/devices/platform/kgsl-3d0/kgsl/kgsl-3d0/pwrscale/trustzone/governor

# make sure our max gpu clock is set via sysfs
echo 450000000 > /sys/class/kgsl/kgsl-3d0/max_gpuclk

# set min max boot freq to default.
echo "1890000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;
echo "384000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;

# Fix ROM dev wrong sets.
setprop persist.adb.notify 0
setprop persist.service.adb.enable 1
setprop dalvik.vm.execution-mode int:jit
setprop pm.sleep_mode 1

if [ ! -d /data/.ael ]; then
	$BB mkdir -p /data/.ael;
fi;

$BB chmod -R 0777 /data/.ael/;

. /res/customconfig/customconfig-helper;

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.ael/.ccxmlsum`" ];
then
   $BB rm -f /data/.ael/*.profile;
   echo ${ccxmlsum} > /data/.ael/.ccxmlsum;
fi;

[ ! -f /data/.ael/default.profile ] && cp /res/customconfig/default.profile /data/.ael/default.profile;
[ ! -f /data/.ael/battery.profile ] && cp /res/customconfig/battery.profile /data/.ael/battery.profile;
[ ! -f /data/.ael/balanced.profile ] && cp /res/customconfig/balanced.profile /data/.ael/balanced.profile;
[ ! -f /data/.ael/performance.profile ] && cp /res/customconfig/performance.profile /data/.ael/performance.profile;

read_defaults;
read_config;

# cpu
echo "$scaling_governor" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor;
echo "$scaling_min_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq;
echo "$scaling_max_freq" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq;

# zram 700M
if [ "$sammyzram" == "on" ];then
UNIT="M"
/system/bin/rtccd3 -a "$zramdisksize$UNIT"
fi;

# dynamic fsync
if [ "$Dyn_fsync_active" == "on" ];then
echo "1" > /sys/kernel/dyn_fsync/Dyn_fsync_active;
else
echo "0" > /sys/kernel/dyn_fsync/Dyn_fsync_active;
fi;

if [ "$logger_mode" == "on" ]; then
	echo "1" > /sys/kernel/logger_mode/logger_mode;
else
	echo "0" > /sys/kernel/logger_mode/logger_mode;
fi;

# scheduler
echo "$int_scheduler" > /sys/block/mmcblk0/queue/scheduler;
echo "$int_read_ahead_kb" > /sys/block/mmcblk0/bdi/read_ahead_kb;
echo "$ext_scheduler" > /sys/block/mmcblk1/queue/scheduler;
echo "$ext_read_ahead_kb" > /sys/block/mmcblk1/bdi/read_ahead_kb;

# busybox addons
if [ -e /system/xbin/busybox ] && [ ! -e /sbin/ifconfig ]; then
	$BB ln -s /system/xbin/busybox /sbin/ifconfig;
fi;

# enable kmem interface for everyone by GM
echo "0" > /proc/sys/kernel/kptr_restrict;

# apply STweaks defaults
export CONFIG_BOOTING=1
/res/uci.sh apply
export CONFIG_BOOTING=

OPEN_RW;

# in case zram is disabled
if [ "$sammyzram" == "off" ];then
echo "0" > /proc/sys/vm/swappiness;
fi;

# (
	# Start any init.d scripts that may be present in the rom or added by the user
#	if [ "$init_d" == "on" ]; then
		$BB chmod 755 /system/etc/init.d/*;
		$BB run-parts /system/etc/init.d/;
#	fi;

	# ROOT activation if supersu used
	if [ -e /system/app/SuperSU.apk ] && [ -e /system/xbin/daemonsu ]; then
		if [ "$(pgrep -f "/system/xbin/daemonsu" | wc -l)" -eq "0" ]; then
			/system/xbin/daemonsu --auto-daemon &
		fi;
	fi;

if [ ! -f /system/app/STweaks.apk ] ; then
	$BB rm -f /system/app/STweaks.apk > /dev/null 2>&1;
	$BB rm -f /data/app/STweaks.apk > /dev/null 2>&1;
	$BB rm -f /system/app/STweaks.apk > /dev/null 2>&1;
	$BB rm -f /data/app/com.gokhanmoral.stweaks* > /dev/null 2>&1;
	$BB rm -f /data/data/com.gokhanmoral.stweaks*/* > /dev/null 2>&1;
	$BB cp /res/STweaks.apk /system/app/;
	$BB chown root.root /system/app/STweaks.apk;
	$BB chmod 644 /system/app/STweaks.apk;
fi;

	# disabling knox security at boot
	pm disable com.sec.knox.seandroid;
	setenforce 0;

# Special kernel tweaks (thx to nfsmw_gr)
if [ "$tweaks" == "on" ];then

echo "256" > /proc/sys/fs/inotify/max_user_instances;
echo "32000" > /proc/sys/fs/inotify/max_queued_events;
echo "10" > /proc/sys/kernel/panic;
echo "10" > /proc/sys/fs/lease-break-time;
echo "6144,87380,524288" > /proc/sys/net/ipv4/tcp_rmem;
echo "524288" > /proc/sys/kernel/threads-max;
echo "524288" > /proc/sys/fs/file-max;
echo "65536" > /proc/sys/kernel/msgmax;
echo "6144,87380,524288" > /proc/sys/net/ipv4/tcp_wmem;
echo "500,512000,64,2048" > /proc/sys/kernel/sem;
echo "524288" > /proc/sys/net/core/wmem_max;
echo "8192" > /proc/sys/vm/min_free_kbytes;
echo "524288" > /proc/sys/net/core/rmem_max;
echo "90" > /proc/sys/vm/dirty_ratio;
echo "268435456" > /proc/sys/kernel/shmmax;
echo "250" > /proc/sys/vm/dirty_expire_centisecs;
echo "1" > /proc/sys/vm/drop_caches;
echo "2048" > /proc/sys/kernel/msgmni;
echo "2" > /proc/sys/vm/min_free_order_shift;
echo "10240" > /proc/sys/fs/inotify/max_user_watches;
echo "70" > /proc/sys/vm/dirty_background_ratio;
echo "1" > /proc/sys/net/ipv4/tcp_tw_recycle;
echo "1" > /proc/sys/vm/overcommit_memory;
echo "50" > /proc/sys/vm/overcommit_ratio;  

    if [ "$sammyzram" == "on" ];then
      echo "80" > /proc/sys/vm/swappiness;
    else
      echo "0" > /proc/sys/vm/swappiness;
    fi;

fi;

	# Fix critical perms again after init.d mess
	CRITICAL_PERM_FIX;


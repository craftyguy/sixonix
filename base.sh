#!/bin/bash

# Example ways to use this script:
# Run GBM piglit with custom mesa:
#	gbm.sh /foo/bar/mesa/lib PIGLIT [extra piglit args] results/dir
# Run GBM piglit with system mesa:
#	gbm.sh /usr/lib PIGLIT results/dir
# Run GLX egypt benchmark with custom mesa:
#	glx.sh /foo/bar/mesa/lib EGYPT
# Run GLX with menu and custom mesa:
#	glx.sh /foo/bar/mesa/lib
# Run GLX with menu and system mesa:
#	glx.sh

# By default the script will try to use the native resolution. However in
# failure cases, it will warn and fall back to this resolution.
declare -r DEFAULT_RES_X=1920
declare -r DEFAULT_RES_Y=1080

# Customize this to your own environments.
declare -r BENCHDIR=/opt/benchmarks/
declare -r DEFAULT_LIBS=/usr/lib/xorg/modules/

declare -r EXPECTED_VERSION=1.3

function get_benchmarks_version() {
	if [ ! -f ${BENCHDIR}/VERSION ] ; then
		export BENCH_VERSION="pre-release"
	else
		export BENCH_VERSION=$(head -n 1 ${BENCHDIR}/VERSION)
	fi
}

function get_hang_count() {
	return $(dmesg | grep "GPU HANG" | wc -l)
}

function init() {
	[[ -z $DISPLAY ]] && echo "Inappropriate call to init" && exit 1
	if hash xset 2>/dev/null; then
		xset -dpms; xset s off
	fi
	if hash xscreensaver-command 2>/dev/null; then
		xscreensaver-command -deactivate >/dev/null 2>&1
	fi

	get_benchmarks_version
	if [[ "$EXPECTED_VERSION" != "$BENCH_VERSION" ]] ; then
		echo "Unexpected benchmark version: $EXPECTED_VERSION != $BENCH_VERSION"
	fi

	# Get a count of number of GPU hangs at the start of the run
	get_hang_count
	export HANG_COUNT=$?
}

function env_sanitize() {
	unset BENCH_VERSION
	unset DISPLAY
	unset EGL_DRIVERS_PATH
	unset EGL_PLATFORM
	unset HANG_COUNT
	unset LD_LIBRARY_PATH
	unset LIBGL_DRIVERS_PATH
	unset PIGLIT_PLATFORM
	unset RES_X
	unset RES_Y
	unset vblank_mode
}

function get_dimensions() {
	if hash xdpyinfo 2>/dev/null; then
		read RES_X RES_Y <<< $(xdpyinfo | grep dimensions | \
			awk '{print $2}' | awk -Fx '{print $1, $2}')
	else
		echo "WARNING: COULDN'T GET DIMENSIONS"
		RES_X=$DEFAULT_RES_X
		RES_Y=$DEFAULT_RES_Y
	fi
	export RES_X
	export RES_Y
}

function set_dimensions() {
	local newX=$1
	local newY=$2
	output=$(xrandr | grep -E " connected (primary )?[1-9]+" | \
		sed -e "s/\([A-Z0-9]\+\) connected.*/\1/")
	xrandr --output $output --mode ${newX}x${newY}

	get_dimensions
}

function glx_env() {
	env_sanitize

	local path=${1}

	export vblank_mode=0
	export LD_LIBRARY_PATH=$path
	export LIBGL_DRIVERS_PATH=$path/dri
	export DISPLAY=:0
	set +o nounset
	[[ -z $RES_X ]] && get_dimensions
}

function gbm_env() {
	env_sanitize

	local path=${1}

	export vblank_mode=0
	export LD_LIBRARY_PATH=$path
	export LIBGL_DRIVERS_PATH=$path/dri
	export EGL_DRIVERS_PATH=${LIBGL_DRIVERS_PATH}
	export EGL_PLATFORM=drm
	export PIGLIT_PLATFORM=gbm
}

function dump_system_info() {
	get_benchmarks_version
	echo $(uname -rvmp) >> $2
	echo "Benchmark version: ${BENCH_VERSION}" >> $2
	for mesa in $1; do
		mesa_ver=$(strings $mesa/usr/local/lib/dri/i965_dri.so  | grep 'git-' | \
			awk '{print $3 " " $4}')
		echo "$mesa = $mesa_ver" >> $2
	done
}

function is_debug_build() {
	local mesa_dir=$1
	readelf -s ${mesa_dir}/dri/i965_dri.so | grep -q nir_validate_shader
	return $?
}

function check_gpu_hang() {
	get_hang_count
	local count=$?
	if [[ $count -gt $HANG_COUNT ]] ; then
		export HANG_COUNT=$count
		return 0
	else
		return 1
	fi
}

SCRIPT_PATH=$(realpath $(dirname $BASH_SOURCE))
CONFIGS_PATH=${SCRIPT_PATH}/conf.d/
declare -A TESTS

for conf_file in ${CONFIGS_PATH}/*.sh; do
	source "$conf_file"
done

# If sourced from another script, just leave
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return

# IF our script name was gbm.sh, setup the GBM environment. If it was named
# glx, then do the usual thing. Default to local mesa install
script_name=`basename $0`
if [[ $script_name = "gbm.sh" ]] ; then
	gbm_env ${1:-$DEFAULT_LIBS}
	shift || true
elif [[ $script_name = "glx.sh" ]] ; then
	glx_env ${1:-$DEFAULT_LIBS}
	shift || true
fi

[[ -n $SKIP_RUNNER_INIT ]] || init

if [[ $# -eq 0 ]]; then

	# SYNMARK is not runnable from the selector menu because it requires a
	# second argument. Remove it from the array before displaying the
	# choices.
	unset TESTS[SYNMARK]
	unset TESTS[SYNMARK_LONG]
	prompt="Pick an option:"

	PS3="Select test (just hit ctrl+c to exit)"
	select test in ${!TESTS[*]} "Exit"; do
	    case "$REPLY" in
	    *) eval "${TESTS[$test]}";;
	    esac
	done
else
	index=$1
	shift
	set -o nounset
	eval "${TESTS[$index]} $*"
	set +o nounset
fi

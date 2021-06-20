#!/usr/bin/env bash

usage () {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	{
		echo "${script_name} - Utility for managing fail safe boot."
		echo "Usage: ${script_name} [flags]"
		echo "Option flags:"
		echo "  -c --fsb-counter - Set fsb-counter value. Default='${fsb_counter}'."
		echo "  -m --fsb-map     - Set fsb-map value. Default='${fsb_map}'."
		echo "  -i --fsb-index   - Set fsb-index value. Default='${fsb_index}'."
		echo "  -n --efi-next    - Set EFI BootNext value. Default='${efi_next}'."
		echo "  -p --print       - Print current variable values."
		echo "  -h --help        - Show this help and exit."
		echo "  -v --verbose     - Verbose execution."
		echo "  -g --debug       - Extra verbose execution."
		echo "  -d --dry-run     - Dry run, don't modify variables."
		echo "Info:"
		echo '  @PACKAGE_NAME@ v@PACKAGE_VERSION@'
		echo '  @PACKAGE_URL@'
		echo "  Send bug reports to: Geoff Levand <geoff@infradead.org>."
	} >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="c:m:i:n:phvgd"
	local long_opts="fsb-counter:,fsb-map:,fsb-index:,efi-next:,print,help,verbose,debug,dry-run"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		# echo "${FUNCNAME[0]}: (${#}) '${*}'"
		case "${1}" in
		-c | --fsb-counter)
			fsb_counter="${2}"
			shift 2
			;;
		-m | --fsb-map)
			fsb_map="${2}"
			shift 2
			;;
		-i | --fsb-index)
			fsb_index="${2}"
			shift 2
			;;
		-n | --efi-next)
			efi_next="${2}"
			shift 2
			;;
		-p | --print)
			print=1
			shift
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			verbose=1
			debug=1
			set -x
			shift
			;;
		-d | --dry-run)
			dry_run=1
			shift
			;;
		--)
			shift
			extra_args="${*}"
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}
	local sec="${SECONDS}"

	if [[ -d "${tmp_dir:-}" ]]; then
		if [[ ${keep_tmp_dir:-} ]]; then
			echo "${script_name}: INFO: tmp dir preserved: '${tmp_dir}'" >&2
		else
			rm -rf "${tmp_dir:?}"
		fi
	fi

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

on_err() {
	local f_name=${1}
	local line_no=${2}
	local err_no=${3}
	echo "${script_name}: ERROR: (${err_no}) at ${f_name}:${line_no}." >&2
	exit ${err_no}
}

check_prog() {
	local prog="${1}"
	local result;

	result=0
	if ! test -x "$(command -v "${prog}")"; then
		echo "${script_name}: ERROR: Please install '${prog}'." >&2
		result=1
	fi

	return ${result}
}

dump_vars() {
	local msg=${1}

	{
		echo "${msg}"
		hexdump -e '"BootCurrent: " 8/1 "%02x " "\n"' < "${efi_mnt}/BootCurrent-${efi_vendor_id}" || :
		hexdump -e '"BootNext:    " 8/1 "%02x " "\n"' < "${efi_mnt}/BootNext-${efi_vendor_id}" || :
		hexdump -e '"fsb-counter: " 8/1 "%02x " "\n"' < "${efi_mnt}/fsb-counter-${fsb_vendor_id}" || :
		hexdump -e '"fsb-map:     " 8/1 "%02x " "\n"' < "${efi_mnt}/fsb-map-${fsb_vendor_id}" || :
		hexdump -e '"fsb-index:   " 8/1 "%02x " "\n"' < "${efi_mnt}/fsb-index-${fsb_vendor_id}" || :
		echo
	} >&1
}

to_hex_16() {
	local name=${1}
	local in=${2}
	local out=${2}

	if [[ "${in:0:2}" == '0x' ]]; then
		out="${in#0x}"
	elif [[ "${in:(-1)}" == 'h' ]]; then
		out="${in%h}"
	else
		out="$(printf "%04x" "${in}")"
	fi

	if [[ ${verbose} ]]; then
		echo "${FUNCNAME[0]}: '${in}' -> '${out}'" >&2
	fi

	if (( ${#out} != 4 )); then
		echo "${FUNCNAME[0]}: ERROR: Bad value: ${name} '${in}'" >&2
		exit 1
	fi

	echo "${out}"
}

set_var_16() {
	local vendor_id=${1}
	local name=${2}
	local value=${3}

	local file="${efi_mnt}/${name}-${vendor_id}"

	echo "Set ${name}: ${value}"

	local hex_value
	hex_value="$(to_hex_16 "${name}" "${value}")"

	if [[ ! ${dry_run} ]]; then
		chattr -i "${file}" 2>&1 > /dev/null || :
		printf "\x07\x00\x00\x00\x${hex_value:2:2}\x${hex_value:0:2}" > "${file}"
		if [[ ${verbose} ]]; then
			hexdump -e "\"read ${name}:   \" 8/1 \"%02x \" \"\n\"" < "${file}"
		fi
	fi
}

test_1() {
	verbose=1

	for (( i = 0; i <= 65535; i += 1 )); do
		to_hex_16 "${i}" "${i}"
	done
}

test_2() {
	verbose=1
#	dry_run=1

#	for (( i = 0; i <= 65535; i += 30 )); do
	for (( i = 2559; i <= 2561; i += 1 )); do
		set_var_16 "${fsb_vendor_id}" "fsb-test" "${i}"
		echo
	done

	chattr -i "${efi_mnt}/fsb-test-${fsb_vendor_id}"
	rm -f "${efi_mnt}/fsb-test-${fsb_vendor_id}"
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-main}):\[\e[0m\] '

script_name="${0##*/}"
base_name="${script_name##*/%}"
base_name="${base_name%.sh*}"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}

start_time="$(date +%Y.%m.%u-%H.%M.%S)"
SECONDS=0

trap "on_exit 'Failed'" EXIT
trap 'on_err ${FUNCNAME[0]:-main} ${LINENO} ${?}' ERR
set -eE
set -o pipefail
set -o nounset

fsb_counter=''
fsb_map=''
fsb_index=''
efi_next=''
print=''
usage=''
verbose=''
debug=''
dry_run=''

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ${extra_args} ]]; then
	set +o xtrace
	echo "${script_name}: ERROR: Got extra args: '${extra_args}'" >&2
	usage
	exit 1
fi

hexdump="${hexdump:-hexdump}"

if ! check_prog "${hexdump}"; then
	exit 1
fi

attr_ba_ra='06'
attr_nv_ba_ra='07'

efi_mnt="/sys/firmware/efi/efivars"

efi_vendor_id="8be4df61-93ca-11d2-aa0d-00e098032b8c"
fsb_vendor_id="9c4b2ad9-cff6-485b-ac30-5398aec7605c"

# test_1
# test_2
# exit

op_code="${fsb_counter}${fsb_map}${fsb_index}${efi_next}"

if [[ ! ${op_code} ]]; then
	print=1
fi

if [[ ${print} ]]; then
	dump_vars '--- Current ---'
	trap "on_exit 'Success'" EXIT
	exit 0
fi

if [[ ${verbose} ]]; then
	dump_vars '--- Before ---'
fi

if [[ ${fsb_counter} ]]; then
	set_var_16 "${fsb_vendor_id}" "fsb-counter" "${fsb_counter}"
fi

if [[ ${fsb_map} ]]; then
	set_var_32 "${fsb_vendor_id}" "fsb-map" "${fsb_map}"
fi

if [[ ${fsb_index} ]]; then
	set_var_16 "${fsb_vendor_id}" "fsb-index" "${fsb_index}"
fi

if [[ ${efi_next} ]]; then
	set_var_16 "${efi_vendor_id}" "BootNext" "${efi_next}"
fi

if [[ ${verbose} ]]; then
	echo
	dump_vars '--- After ---'
fi

trap "on_exit 'Success'" EXIT
exit 0

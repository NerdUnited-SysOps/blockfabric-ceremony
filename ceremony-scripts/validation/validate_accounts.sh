#!/usr/bin/zsh

set -e

# This should be a directory, which is where the keystore and password files will go
FIND_PATH="./"
ETHKEY=${HOME}/go/bin/ethkey

usage() {
	echo "Options"
	echo "  -e : Path to ethkey"
	echo "  -h : This help message"
	echo "  -p : The path to find accounts in"
}

while getopts e:hp: option; do
	case "${option}" in
		e)
			ETHKEY=${OPTARG}
			;;
		h)
			usage
			exit 0
			;;
		p)
			FIND_PATH=${OPTARG}
			;;
	esac
done

inspect() {
	inspect_path=$1
	${ETHKEY} inspect \
		--passwordfile ${inspect_path}/password \
		${inspect_path}/keystore
}

print_line() {
	tab1=$1
	tab2=$2
	max_len=$3

	STRING_LENGTH=${#tab1}
	CHARACTERS_TO_PRINT=$(($max_len - $STRING_LENGTH))

	printf "\n${tab1}"
	printf -- " %.0s" $(seq 0 $CHARACTERS_TO_PRINT)
	printf "\t${tab2}"
}

find_dir() {
	dir_path=$1
	line_length=$2

	if [[ -f "${dir_path}/password" ]] && [[ -f "${dir_path}/keystore" ]]; then
		inspect_content=$(inspect "${dir_path}")
		address=$(echo "${inspect_content}" | sed -n -e 's/.*Address:\ *//p')
		print_line "${dir_path}" "${address}" "${line_length}"
	fi
}

longest_entry() {
	arr=(${(@s: :)1})

	m=-1
	for x in ${arr[@]}; do
		[ ${#x} -gt $m ] && m=${#x}
	done
	print $m
}

all_paths=(`find ${FIND_PATH} -type d`)
key_count=$(find ${FIND_PATH} -type d | wc -l)

line_length=$(longest_entry "${all_paths}")
printf "Inspecting $(($key_count - 1)) Keys\n"
print_line "Directory" "Address\n" "${line_length}"
printf -- "-%.0s" $(seq 0 $(($line_length + $line_length)))
printf "\n"

m=0
lines=()
for p in $all_paths; do
	lines+=$(find_dir $p "${line_length}" &)
	if (( $m % 5 == 0 )); then
		wait
		for l in $lines; do
			printf "$l"
		done
		lines=()
	fi
	m=$(($m+1))
done
wait
for l in $lines; do
	printf "$l"
done
lines=()


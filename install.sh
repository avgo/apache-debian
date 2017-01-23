#!/bin/bash




script_rp="$(realpath "${0}")"          || exit 1

# Каталог где хранится скрипт.
#
script_dir="$(dirname "${script_rp}")"  || exit 1

# Каталог для работы данного скрипта куда
# будут сохранены все файлы.
# 1. Нужно где-то хранить исходники.
# 2. Нужно куда-то установить Apache server.
# Пусть по умолчанию берётся из конфига.
#
# install_root="${script_dir}"

if test x"${install_root}" = x
then
	install_root="${script_dir}/root"
	test -d "${install_root}" || mkdir -v "${install_root}"
elif ! test -d "${install_root}"
then
	echo "error: \${install_root}='${install_root}' not exists."
	exit 1
fi

# Порт для Apache сервера.
#
apache2_port=10000

# Каталог куда будут загружен исходный код apache
#
distrib_dir="${install_root}/distrib"

# Каталог данных для тестирования
#
tests_dir="${install_root}/tests"




build_dep() {
	echo building dependencies ...
	su -c "'${script_rp}' --build-dep"
}

prepare_distrib() {
	printf "checking for distrib in '%s' .. " "${distrib_dir}"

	if test -d "${distrib_dir}"
	then
		echo exists
	else
		echo no
		echo creating directory and downloading apache sources...
		mkdir -v "${distrib_dir}"
		cd "${distrib_dir}"
		apt-get source apache2
	fi
}

prepare_src() {
	local is_overwrite

	if test x"${1}" = x--overwrite; then
		is_overwrite=y
		shift
	fi

	if test x"${1}" = x; then
		echo "prepare_src() error:"
		exit 1
	fi

	local src_dir="${1}"
	local is_create

	echo "prepare_src() starting ..."

	if test -d "${src_dir}"
	then
		if test x$is_overwrite = xy; then
			rm -rf "${src_dir}"
			printf "overwriting "
			is_create=y
		else
			printf "leaving 'src_dir' in '%s'\n" "${src_dir}"
		fi
	else
		printf "creating "
		is_create=y
	fi

	if test x${is_create} = xy; then
		printf "directory 'src_dir' in '%s' and copying apache sources ..\n" "${src_dir}"
		mkdir -v "${src_dir}"
		cp -rf "${distrib_dir}/apache2-"* "${src_dir}" &&
		echo copying complete.
	fi

	src_dir_apache="$(ls -d "${src_dir}/apache2-"*)"

	cd "${src_dir_apache}" || exit 1
}

test01() {
	local test_dir="${1}"

	local apache2_pid="${test_dir}/apache2.pid"
	local log_dir="${test_dir}/log"
	local prefix_rp="${test_dir}/root"
	local src_dir="${test_dir}/src"

	prepare_src --overwrite "${src_dir}"

	mkdir -v "${log_dir}"

	find > "${log_dir}/0.snapshot.txt"

	./configure --prefix="${prefix_rp}" 2>&1 | tee "${log_dir}/1.configure.log.txt" || exit 1
	find > "${log_dir}/1.configure.snapshot.txt"

	make 2>&1 | tee "${log_dir}/2.make.1.log.txt" || exit 1
	find > "${log_dir}/2.make.snapshot.txt"

	make 2>&1 | tee "${log_dir}/2.make.2.log.txt" || exit 1

	make install 2>&1 | tee "${log_dir}/3.make-install.log.txt" || exit 1

	cd "${install_root}"
	for cf in httpd.conf index.html; do
		sed	-e 's@%APACHE_DEBIAN%@'"${install_root}"'@g' \
			-e 's@%APACHE_DEBIAN_PORT%@'"${apache2_port}"'@g' \
			-e 's@%APACHE_DEBIAN_ROOT%@'"${prefix_rp}"'@g' \
			-e 's@%APACHE_PID%@'"${apache2_pid}"'@g' \
			-e 's@%INSTALL_DATE%@'"$(date +"%d %B %Y, %T")"'@g' \
			"${script_dir}/${cf}.in" > "${cf}"
	done

	touch "mime.types"

	cp "${script_dir}/index.pl.in" "index.pl" && chmod +x "index.pl"

	"${prefix_rp}"/bin/apachectl -f "${install_root}"/httpd.conf

	if test -f "${apache2_pid}"; then
		echo pidfile: ${apache2_pid}
		pid=$(cat "${apache2_pid}")
		echo /proc/$pid
		ls -l /proc/$pid
		echo command to kill: kill -s TERM $pid
	else
		echo "no PID-file !!!"
	fi
}

print_vars () {
    local delim=$1;
    shift;
    for cur_var in "$@";
    do
        echo "printf \"%-15s${delim}\\\"%s\\\"\n\" \"${cur_var}\" \"\${${cur_var}}\";";
    done
}

run_test() {
	if test $# -ne 1; then
		echo "run_test() error:"
		exit 1
	fi

	test_procedure="${1}"

	prepare_distrib

	test -d "${tests_dir}" || mkdir -v "${tests_dir}"

	test_dir="${tests_dir}/${test_procedure}"

	rm -rf "${test_dir}"

	mkdir -v "${test_dir}"

	"${test_procedure}" "${test_dir}"
}

su_build_dep() {
	apt-get build-dep apache2
}




if test $# -eq 0; then
	run_test test01
else
	case "${1}" in
	--build-dep)
		action=su_build_dep
		;;
	*)	echo error: unknown action. >&2
		exit 1
		;;
	esac
fi

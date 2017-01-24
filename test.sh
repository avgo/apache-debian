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
# var_dir="${script_dir}"

if test x"${var_dir}" = x
then
	var_dir="${script_dir}/var"
	test -d "${var_dir}" || mkdir -v "${var_dir}"
elif ! test -d "${var_dir}"
then
	echo "error: \${var_dir}='${var_dir}' not exists."
	exit 1
fi

# Порт для Apache сервера.
#
apache2_port=10000

# Каталог куда будут загружен исходный код apache
#
distrib_dir="${var_dir}/distrib"

# Сгенерированная информация
#
tests_data_dir="${var_dir}/tests"

# Каталог данных для тестирования
#
tests_dir="${script_dir}/tests"




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
	local test_data_dir="${2}"

	local apache2_pid="${test_data_dir}/apache2.pid"
	local log_dir="${test_data_dir}/log"
	local prefix_rp="${test_data_dir}/root"
	local src_dir="${test_data_dir}/src"
	local test_result

	prepare_src --overwrite "${src_dir}"

	mkdir -v "${log_dir}"

	find > "${log_dir}/0.snapshot.txt"

	./configure --prefix="${prefix_rp}" 2>&1 | tee "${log_dir}/1.configure.log.txt" || exit 1
	find > "${log_dir}/1.configure.snapshot.txt"

	make 2>&1 | tee "${log_dir}/2.make.1.log.txt" || exit 1
	find > "${log_dir}/2.make.snapshot.txt"

	make 2>&1 | tee "${log_dir}/2.make.2.log.txt" || exit 1

	make install 2>&1 | tee "${log_dir}/3.make-install.log.txt" || exit 1

	for cf in httpd.conf index.html; do
		sed	-e 's@%APACHE_DEBIAN%@'"${test_data_dir}"'@g' \
			-e 's@%APACHE_DEBIAN_PORT%@'"${apache2_port}"'@g' \
			-e 's@%APACHE_DEBIAN_ROOT%@'"${prefix_rp}"'@g' \
			-e 's@%APACHE_PID%@'"${apache2_pid}"'@g' \
			-e 's@%INSTALL_DATE%@'"$(date +"%d %B %Y, %T")"'@g' \
			"${test_dir}/${cf}.in" > "${test_data_dir}/${cf}"
	done

	touch "${test_data_dir}/mime.types"

	cp "${test_dir}/index.pl.in" "${test_data_dir}/index.pl" &&
	chmod +x "${test_data_dir}/index.pl"

	local apache_ctl="${prefix_rp}/bin/apachectl"

	if ! test -f "${apache_ctl}"; then
		echo "error: '${apache_ctl}' not exists."
		test01_fail
		return 1
	fi

	"${apache_ctl}" -f "${test_data_dir}/httpd.conf"

	if ! test -f "${apache2_pid}"; then
		echo "no PID-file !!!"
		test01_fail
		return 1
	fi

	local resp_html="${test_data_dir}/response.html"

	if test -f "${resp_html}"; then
		echo "Response document is exists!!!"
		test01_fail
		return 1
	fi

	if ! curl -o "${resp_html}" localhost:10000; then
		test01_fail
		return 1
	fi

	if ! grep -q "Test 01 document" "${resp_html}" &> /dev/null
	then
		echo "Bad response document!!!"
		test01_fail
		return 1
	fi

	echo pidfile: ${apache2_pid}
	pid=$(cat "${apache2_pid}")
	echo /proc/$pid
	ls -l /proc/$pid

	kill -s TERM $pid

	sleep 1

	if test -f "${apache2_pid}"; then
		echo "Process still running !!!"
		test01_fail
		return 1
	fi

	echo
	echo TEST RESULT:  OK
	echo
}

test01_fail() {
	echo
	echo TEST RESULT:  FAIL
	echo
}

test02() {
	local test_dir="${1}"
	local test_data_dir="${2}"

	local src_dir="${test_data_dir}/src"

	prepare_src --overwrite "${src_dir}"

	./configure &&
	make
}

run_test() {
	if test $# -ne 1; then
		echo "run_test() error:"
		exit 1
	fi

	test_procedure="${1}"

	prepare_distrib

	test_dir="${tests_dir}/${test_procedure}"

	test -d "${tests_data_dir}" || mkdir -v "${tests_data_dir}"

	test_data_dir="${tests_data_dir}/${test_procedure}"

	rm -rf "${test_data_dir}"

	mkdir -v "${test_data_dir}"

	"${test_procedure}" "${test_dir}" "${test_data_dir}"
}

su_build_dep() {
	apt-get build-dep apache2
}




if test $# -eq 0; then
	if test -f test_plan; then
		cat <<EOF
You can type "$(basename "$(realpath "${0}")") -r" for running
test plan described in 'test_plan' (listed below):
EOF
		cat test_plan
	else
		echo error: test plan needed.
	fi
else
	case "${1}" in
	--build-dep)
		action=su_build_dep
		;;
	-r)
		if test -f test_plan; then
			for ct in $(cat test_plan); do
				run_test $ct
			done
		else
			echo error: test plan needed.
		fi
		;;
	*)	echo error: unknown action. >&2
		exit 1
		;;
	esac
fi

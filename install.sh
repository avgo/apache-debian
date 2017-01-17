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

# Каталог куда будут загружен исходный код apache
#
distrib_dir="${install_root}/distrib"

# Каталог куда будут скопирован исходный код apache для дальнейших
# экспериментов
#
src_dir="${install_root}/src"

# Каталог куда будет установлен apache2
#
prefix_rp="${install_root}/root"

# Логи для процесса сборки/тестирования
#
log_dir="${install_root}/log"

# PID-файл для сервера apache2
#
apache2_pid="${install_root}/apache2.pid"

# Порт для Apache сервера.
#
apache2_port=10000




build_dep() {
	echo building dependencies ...
	su -c "'${script_rp}' --build-dep"
}

install() {
	cd "${install_root}" || return 1

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

	printf "checking for src_dir in '%s' .. " "${src_dir}"

	if test -d "${src_dir}"
	then
		echo exists
	else
		echo no
		echo creating directory and copying apache sources...
		mkdir -v "${src_dir}"
		cp -rf "${distrib_dir}/apache2-"* "${src_dir}" &&
		echo copying complete.
	fi

	src_dir_ap="$(ls -d "${src_dir}/apache2-"*)"

	test -d "${log_dir}" || mkdir "${log_dir}"

	cd "${src_dir_ap}" || exit 1

	find > "${log_dir}/0.snapshot.txt"

	./configure --prefix="${prefix_rp}" 2>&1 | tee "${log_dir}/1.configure.log.txt" || exit 1
	find > "${log_dir}/1.configure.snapshot.txt"

	make 2>&1 | tee "${log_dir}/2.make.log.txt" || exit 1
	find > "${log_dir}/2.make.snapshot.txt"

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

	start
}

kill_httpd() {
	if test -f "${apache2_pid}"; then
		echo killing apache..
		kill -s TERM $(cat "${apache2_pid}")
	fi
}

print_vars ()
{
    local delim=$1;
    shift;
    for cur_var in "$@";
    do
        echo "printf \"%-15s${delim}\\\"%s\\\"\n\" \"${cur_var}\" \"\${${cur_var}}\";";
    done
}

start() {
	"${prefix_rp}"/bin/apachectl -f "${install_root}"/httpd.conf
}

status() {
	if test -f "${apache2_pid}"; then
		pid=$(cat "${apache2_pid}") &&
		echo /proc/$pid
		ls -l /proc/$pid
	else
		echo no PID-file
	fi
}

su_build_dep() {
	apt-get build-dep apache2
}

vars() {
	eval "$(print_vars '' \
		distrib_dir  \
		install_root  \
		script_rp     \
		script_dir    \
		src_dir       \
		prefix_rp     \
		apache2_pid   \
		apache2_port  \
	)"
}




if test $# -eq 0; then
	install
else
	case "${1}" in
	--build-dep)
		action=su_build_dep
		;;
	--clean)
		kill_httpd
		rm -rf	"${log_dir}"   \
			"${src_dir}"   \
			"${prefix_rp}" \
			"${install_root}/error.log"  \
			"${install_root}/httpd.conf" \
			"${install_root}/index.html" \
			"${install_root}/index.pl"   \
			"${install_root}/mime.types"
		;;
	--install)
		install
		;;
	--kill)
		kill_httpd
		;;
	--restart)
		kill_httpd
		start
		;;
	--start)
		start
		;;
	--status)
		status
		;;
	--vars)
		vars
		;;
	*)	echo error: unknown action. >&2
		exit 1
		;;
	esac
fi

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
src_dir="${install_root}/src"

# Каталог куда будет установлен apache2
#
prefix_rp="${install_root}/root"

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

	echo installing ...
	build_dep &&
	mkdir -v "${src_dir}" &&
	cd "${src_dir}" &&
	apt-get source apache2 || exit 1

	log_dir="${install_root}/log"

	test -d "${log_dir}" || mkdir "${log_dir}"

	cd "apache2-"* || exit 1

	# SNAPSHOT before "configure"
	find > "${log_dir}/snapshot.0.txt"

	./configure --prefix="${prefix_rp}" || exit 1

	# SNAPSHOT after "configure"
	find > "${log_dir}/snapshot.1.configure.txt"

	make || exit 1

	# SNAPSHOT after "make"
	find > "${log_dir}/snapshot.2.make.txt"

	make install || exit 1

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
		rm -rf	"${src_dir}"   \
			"${prefix_rp}" \
			"${install_root}/httpd.conf" \
			"${install_root}/index.html" \
			"${install_root}/error.log"
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

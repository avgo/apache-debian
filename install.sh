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
	apt-get source apache2 &&
	cd "apache2-"* &&
	./configure --prefix="${prefix_rp}" && make && make install
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

start() {
	"${prefix_rp}"/bin/apachectl -f "${install_root}"/httpd.conf
}

status() {
	if test -f "${apache2_pid}"; then
		:
	else
		echo no PID-file
	fi
}

su_build_dep() {
	apt-get build-dep apache2
}




if test $# -eq 0; then
	action=install
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
		action=install
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
	*)	echo error: unknown action. >&2
		exit 1
		;;
	esac
fi

$action

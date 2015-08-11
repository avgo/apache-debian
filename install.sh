#!/bin/bash




script_rp="$(realpath "${0}")"          || exit 1
script_dir="$(dirname "${script_rp}")"  || exit 1
# install_root="$(realpath "${script_dir}/..")"
install_root="${script_dir}"
src_dir="${install_root}/src"
prefix_rp="${install_root}/root"
apache2_pid="${install_root}/apache2.pid"




build_dep() {
	echo building dependencies ...
	su -c "'${script_rp}' --build-dep"
}

install() {
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
			-e 's@%APACHE_PID%@'"${apache2_pid}"'@g' \
			-e 's@%APACHE_DEBIAN_ROOT%@'"${prefix_rp}"'@g' \
			-e 's@%INSTALL_DATE%@'"$(date +"%d %B %Y, %T")"'@g' \
			"${cf}".in > "${cf}"
	done
	"${prefix_rp}"/bin/apachectl -f "${install_root}"/httpd.conf
}

kill_httpd() {
	if test -f "${apache2_pid}"; then
		echo killing apache..
		kill -s TERM $(cat "${apache2_pid}")
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
	*)	echo error: unknown action. >&2
		exit 1
		;;
	esac
fi

$action

#!/bin/bash

set -e

# use command submin
hostname="${SUBMIN_HOSTNAME:-submin.local}"
http_vhost="${SUBMIN_HTTP_VHOST:-http://127.0.0.1}"
external_port="${SUBMIN_EXTERNAL_PORT:-80}"
data_dir="${SUBMIN_DATA_DIR:-/var/lib/submin/data}"
svn_repo="${SUBMIN_SVN_DIR:-/var/lib/submin/data/svn}"
admin_mail="${SUBMIN_ADMIN_MAIL:-root@submin.local}"

echo "Prepare submin..."
if [ ! -e ${data_dir} ]; then
	echo "Initing repo and config..."
    echo -e "svn\n${svn_repo}\n${hostname}:${external_port}\n\n\n" \
        | submin2-admin ${data_dir} initenv ${admin_mail} >/dev/null
    chown www-data:www-data ${svn_repo}
    submin2-admin ${data_dir} apacheconf create all >/dev/null 2>&1 || true
	# disable git
    submin2-admin ${data_dir} config set vcs_plugins svn || true
	# set http_vhost
	submin2-admin ${data_dir} config set http_vhost ${http_vhost} || true

    key=`echo "SELECT key FROM password_reset;" | sqlite3 ${data_dir}/conf/submin.db`
    echo "Access ${http_vhost}:${external_port}/submin/password/admin/${key} to reset password"
else
	chown www-data:www-data ${svn_repo}
    submin2-admin ${data_dir} apacheconf create all >/dev/null 2>&1 || true
	# disable git
    submin2-admin ${data_dir} config set vcs_plugins svn || true
	# set http_vhost
	submin2-admin ${data_dir} config set http_vhost ${http_vhost} || true
fi

if [ ! -e /etc/apache2/conf-available/apache-2.4-webui-cgi.conf ]; then
	echo "Initing apache2..."
	ln -s ${data_dir}/conf/apache-2.4-webui-cgi.conf /etc/apache2/conf-available/
	ln -s ${data_dir}/conf/apache-2.4-svn.conf /etc/apache2/conf-available/
	{
		a2enconf apache-2.4-webui-cgi
		a2enconf apache-2.4-svn
		a2enmod authn_dbd
		a2enmod rewrite
		a2enmod cgid
	} >/dev/null 2>&1
fi
service apache2 restart
echo "Everything done.Enjoy submin."

tail -f /var/log/apache2/access.log

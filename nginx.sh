#!/usr/bin/env bash

set -euo pipefail

function help() {
    cat <<EOF

Execute:
$ bash ${0##*\/} -l localPublicKeyFile.asc -r fullPathToPublicKeyFileOnNginxServer

I personal use the WKD file. Example:
$ gpg --export --armor maria.musterfrau@example.org > pubkey.asc
$ bash ${0##*\/} -l pubkey.asc -r /var/www/openpgpkey_example/.well-known/openpgpkey/example.org/hu/asdfasdfasdfasdfasdfasdfasdfasdf

EOF

    return 1
}

while getopts l:r:h opt; do
    case $opt in
        l) LOCAL_PUBLIC_KEY_FILE="${OPTARG}";;
        r) NGINX_ABSOLUTE_FILE_PATH="${OPTARG}";;
        h|?) help;;
    esac
done

if [ -z ${LOCAL_PUBLIC_KEY_FILE+x} ] || [ -z ${NGINX_ABSOLUTE_FILE_PATH+x} ]; then
    help
fi

KEYS="$(gpg --with-colons --show-keys "${LOCAL_PUBLIC_KEY_FILE}")"
GPG_REGEX="$(
    paste -d '|' -s <(
        paste -d '|' -s <(
            grep "^fpr:" <<<"${KEYS}" | cut -d: -f10
            grep -e "^pub:" -e "^sub:" <<<"${KEYS}" | cut -d: -f5
        ) | sed -e 's/^/(/' -e 's/$/)/' -e 's/^/(0x|)/'
        grep "^uid:" <<<"${KEYS}" | cut -d: -f10 | awk -F'[<>]' '{print $2}' | paste -d '|' -s -  | tr -d '\n'
) | sed -e 's/^/(/' -e 's/$/)/')"
KEY_ID="$(gpg --list-options show-only-fpr-mbox --show-keys "${LOCAL_PUBLIC_KEY_FILE}" | awk '{print $1}')"

cat <<EOF
location = /pks/lookup {

    if (\$query_string !~ "^(.+&op=get&.+|.+&op=get|op=get&.+)$") {
        return 501;
    }

    if (\$query_string !~ "^(.+&search=.+&.+|.+&search=.+|search=.+&.+)$") {
        return 501;
    }

    if (\$query_string !~* "^((.+&|)op=get(&|&.+&)search=${GPG_REGEX}(&.+|)|(.+&|)search=${GPG_REGEX}(&|&.+&)op=get(&.+|))$") {
        return 404;
    }

    add_header content-disposition "attachment; filename=${KEY_ID}.asc";
    default_type application/pgp-keys;
    alias "${NGINX_ABSOLUTE_FILE_PATH}";
}
EOF

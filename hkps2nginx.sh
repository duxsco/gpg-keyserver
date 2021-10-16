#!/usr/bin/env bash

set -euo pipefail

function help() {
    cat <<EOF

Execute:
$ bash ${0##*\/} -l localPublicKeysFile.asc -r NginxWebroot

Example:
$ gpg --export --armor maria.musterfrau@example.org work@example.org > pubkey.asc
$ bash ${0##*\/} -l pubkey.asc -r /var/www/keys/

To indent using tabs:
$ bash ${0##*\/} -l pubkey.asc -r /var/www/keys/ | sed 's/    /\t/g' | sed 's/^\([^$]\)/\t\t\1/'
EOF

    return 1
}

while getopts l:r:h opt; do
    case $opt in
        l) LOCAL_PUBLIC_KEY_FILE="${OPTARG}";;
        r) NGINX_KEYS_WEBROOT="${OPTARG}";;
        h|?) help;;
    esac
done

if [ -z ${LOCAL_PUBLIC_KEY_FILE+x} ] || [ -z ${NGINX_KEYS_WEBROOT+x} ]; then
    help
fi

TEMP_GPG_HOMEDIR="$(mktemp -d)"
declare -A GPG_REGEX

gpg --quiet --homedir "${TEMP_GPG_HOMEDIR}" --import "${LOCAL_PUBLIC_KEY_FILE}"
readarray -t GPG_KEY_IDS < <(gpg --homedir "${TEMP_GPG_HOMEDIR}" --list-options show-only-fpr-mbox --list-keys | awk '{print $1}')

for SINGLE_GPG_KEY_ID in "${GPG_KEY_IDS[@]}"; do
    COLONS_OUTPUT="$(gpg --homedir "${TEMP_GPG_HOMEDIR}" --with-colons --list-keys "${SINGLE_GPG_KEY_ID}")"
    GPG_REGEX["${SINGLE_GPG_KEY_ID}"]="$(
        paste -d '|' -s <(
            paste -d '|' -s <(
                grep "^fpr:" <<<"${COLONS_OUTPUT}" | cut -d: -f10
                grep -e "^pub:" -e "^sub:" <<<"${COLONS_OUTPUT}" | cut -d: -f5
            ) | sed -e 's/^/(/' -e 's/$/)/' -e 's/^/(0x|)/'
            grep "^uid:" <<<"${COLONS_OUTPUT}" | cut -d: -f10 | awk -F'[<>]' '{print $2}' | paste -d '|' -s -  | tr -d '\n'
    ) | sed -e 's/^/(/' -e 's/$/)/')"
done

gpgconf --homedir "${TEMP_GPG_HOMEDIR}" --kill all

cat <<EOF
location ~ "^/([A-F0-9]{40})\.asc$" {
    add_header content-disposition "attachment; filename=\$1.asc";
    default_type application/pgp-keys;
    root ${NGINX_KEYS_WEBROOT};
}

location = /pks/lookup {

    if (\$query_string !~ "^(.+&op=get&.+|.+&op=get|op=get&.+)$") {
        return 501;
    }

    if (\$query_string !~ "^(.+&search=.+&.+|.+&search=.+|search=.+&.+)$") {
        return 501;
    }
EOF

for SINGLE_GPG_KEY_ID in "${GPG_KEY_IDS[@]}"; do
    cat <<EOF

    if (\$query_string ~* "^((.+&|)op=get(&|&.+&)search=${GPG_REGEX["${SINGLE_GPG_KEY_ID}"]}(&.+|)|(.+&|)search=${GPG_REGEX["${SINGLE_GPG_KEY_ID}"]}(&|&.+&)op=get(&.+|))$") {
        return 301 /${SINGLE_GPG_KEY_ID}.asc;
    }
EOF

done

cat <<EOF

    return 404;
}
EOF

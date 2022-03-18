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

if [[ -z ${LOCAL_PUBLIC_KEY_FILE} ]] || [[ -z ${NGINX_KEYS_WEBROOT} ]]; then
    help
fi

TEMP_GPG_HOMEDIR="$(mktemp -d)"
declare -A GPG_REGEX

gpg --quiet --homedir "${TEMP_GPG_HOMEDIR}" --import "${LOCAL_PUBLIC_KEY_FILE}"
readarray -t GPG_KEY_IDS < <(gpg --homedir "${TEMP_GPG_HOMEDIR}" --with-colons --list-keys | grep -A1 "^pub:" | grep "^fpr:" | cut -d: -f10)

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
location ~ "^/([A-F0-9]{40})\.asc\$" {
    add_header content-disposition "attachment; filename=\$1.asc";
    default_type application/pgp-keys;
    root ${NGINX_KEYS_WEBROOT};
}

location = /pks/lookup {

    # if query doesn't contain "op=get"
    if (\$query_string !~ "^(.+&)*op=get(&.+)*\$") {
        return 501;
    }

    # if query doesn't contain "search=..."
    if (\$query_string !~ "^(.+&)*search=((0x|)([0-9a-fA-F]{8}|[0-9a-fA-F]{16}|[0-9a-fA-F]{40})|.+@.+)(&.+)*\$") {
        return 501;
    }

    # if query contains more than one "op=get"
    if (\$query_string ~ "^(.+&)*op=.+&(.+&)*op=.+(&.+)*\$") {
        return 501;
    }

    # if query contains more than one "search=..."
    if (\$query_string ~ "^(.+&)*search=.+&(.+&)*search=.+(&.+)*\$") {
        return 501;
    }
EOF

for SINGLE_GPG_KEY_ID in "${GPG_KEY_IDS[@]}"; do
    cat <<EOF

    if (\$query_string ~* "^(.+&)*search=${GPG_REGEX["${SINGLE_GPG_KEY_ID}"]}(&.+)*\$") {
        return 301 /${SINGLE_GPG_KEY_ID}.asc;
    }
EOF

done

cat <<EOF

    return 404;
}
EOF

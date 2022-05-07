#!/usr/bin/env bash

# Prevent tainting variables via environment
# See: https://gist.github.com/duxsco/fad211d5828e09d0391f018834f955c9
unset colons_output gpg_key_ids gpg_regex local_public_key_file nginx_keys_webroot single_gpg_key_id temp_gpg_homedir

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
}

while getopts l:r:h opt; do
    case $opt in
        l) local_public_key_file="$OPTARG";;
        r) nginx_keys_webroot="$OPTARG";;
        h) help; exit 0;;
        ?) help; exit 1;;
    esac
done

if [[ -z ${local_public_key_file} ]] || [[ -z ${nginx_keys_webroot} ]]; then
    help
    exit 1
fi

temp_gpg_homedir="$(mktemp -d)"
declare -A gpg_regex

gpg --quiet --homedir "${temp_gpg_homedir}" --import "${local_public_key_file}"
readarray -t gpg_key_ids < <(gpg --homedir "${temp_gpg_homedir}" --with-colons --list-keys | grep -A1 "^pub:" | grep "^fpr:" | cut -d: -f10)

for single_gpg_key_id in "${gpg_key_ids[@]}"; do
    colons_output="$(gpg --homedir "${temp_gpg_homedir}" --with-colons --list-keys "${single_gpg_key_id}")"
    gpg_regex[$single_gpg_key_id]="$(
        paste -d '|' -s <(
            paste -d '|' -s <(
                grep "^fpr:" <<<"${colons_output}" | cut -d: -f10
                grep "^fpr:" <<<"${colons_output}" | cut -d: -f10 | grep -Eo "^.{50}"
                grep -e "^pub:" -e "^sub:" <<<"${colons_output}" | cut -d: -f5
                grep -e "^pub:" -e "^sub:" <<<"${colons_output}" | cut -d: -f5 | grep -Eo ".{8}$"
            ) | sed -e 's/^/(/' -e 's/$/)/' -e 's/^/(0x|)/'
            grep "^uid:" <<<"${colons_output}" | cut -d: -f10 | awk -F'[<>]' '{print $2}' | paste -d '|' -s -  | tr -d '\n'
    ) | sed -e 's/^/(/' -e 's/$/)/')"
done

gpgconf --homedir "${temp_gpg_homedir}" --kill all

cat <<EOF
location ~ "^/([A-F0-9]{40}|[0-9A-F]{50})\.asc\$" {
    add_header content-disposition "attachment; filename=\$1.asc";
    default_type application/pgp-keys;
    root ${nginx_keys_webroot};
}

location = /pks/lookup {

    # if query doesn't contain "op=get"
    if (\$query_string !~ "^(.+&)*op=get(&.+)*\$") {
        return 501;
    }

    # if query doesn't contain "search=..."
    if (\$query_string !~ "^(.+&)*search=((0x|)([0-9a-fA-F]{8}|[0-9a-fA-F]{16}|[0-9a-fA-F]{40}|[0-9a-fA-F]{50})|.+@.+)(&.+)*\$") {
        return 501;
    }

    # if query contains more than one "op=get"
    if (\$query_string ~ "^(.+&)*op=(.+&)+op=.+(&.+)*\$") {
        return 501;
    }

    # if query contains more than one "search=..."
    if (\$query_string ~ "^(.+&)*search=(.+&)+search=.+(&.+)*\$") {
        return 501;
    }
EOF

for single_gpg_key_id in "${gpg_key_ids[@]}"; do
    cat <<EOF

    if (\$query_string ~* "^(.+&)*search=${gpg_regex[$single_gpg_key_id]}(&.+)*\$") {
        return 301 /${single_gpg_key_id}.asc;
    }
EOF

done

cat <<EOF

    return 404;
}
EOF

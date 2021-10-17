# KISS-like, self-hosted GnuPG keyserver

Following [draft RFC](https://datatracker.ietf.org/doc/html/draft-shaw-openpgp-hkp-00), `hkps2nginx.sh` creates the Nginx configuration for hosting your own GnuPG keyserver which allows only for retrieval of public keys (no sks-like sync, no upload, no index, no vindex).

## System requirements

`hkps2nginx.sh` has been tested on Gentoo Linux and macOS Catalina, both with **GnuPG v2.2.x**. For `hkps2nginx.sh` to function on macOS, you need to install [HomeBrew's](https://brew.sh/) `bash` package:

```bash
brew install bash
```

## Creation of Nginx config

```bash
bash hkps2nginx.sh -h

Execute:
$ bash hkps2nginx.sh -l localPublicKeysFile.asc -r NginxWebroot

Example:
$ gpg --export --armor maria.musterfrau@example.org work@example.org > pubkey.asc
$ bash hkps2nginx.sh -l pubkey.asc -r /var/www/keys/

To indent using tabs:
$ bash hkps2nginx.sh -l pubkey.asc -r /var/www/keys/ | sed 's/    /\t/g' | sed 's/^\([^$]\)/\t\t\1/'
```

Sample `bash hkps2nginx.sh -l pubkey.asc -r /var/www/keys/` output:

```bash
location ~ "^/([A-F0-9]{40})\.asc$" {
    add_header content-disposition "attachment; filename=$1.asc";
    default_type application/pgp-keys;
    root /var/www/keys/;
}

location = /pks/lookup {

    if ($query_string !~ "^(.+&op=get&.+|.+&op=get|op=get&.+)$") {
        return 501;
    }

    if ($query_string !~ "^(.+&search=.+&.+|.+&search=.+|search=.+&.+)$") {
        return 501;
    }

    if ($query_string ~* "^((.+&|)op=get(&|&.+&)search=((0x|)(8DFB189CC3CB185E11EAAC9D7C08B736C1633B42|8C3DEF348CB137FD8738DDC94026E4D290126DCC|62050246C4646021A3FE09A57B7B0F3EDE5BEC71|4397EFC99AADC1E6A322595EB4B5FCD11440A0E1|7C08B736C1633B42|4026E4D290126DCC|7B7B0F3EDE5BEC71|B4B5FCD11440A0E1)|maria.musterfrau@example.org|maria.musterfrau@example.de|maria.musterfrau@example.eu)(&.+|)|(.+&|)search=((0x|)(8DFB189CC3CB185E11EAAC9D7C08B736C1633B42|8C3DEF348CB137FD8738DDC94026E4D290126DCC|62050246C4646021A3FE09A57B7B0F3EDE5BEC71|4397EFC99AADC1E6A322595EB4B5FCD11440A0E1|7C08B736C1633B42|4026E4D290126DCC|7B7B0F3EDE5BEC71|B4B5FCD11440A0E1)|maria.musterfrau@example.org|maria.musterfrau@example.de|maria.musterfrau@example.eu)(&|&.+&)op=get(&.+|))$") {
        return 301 /8DFB189CC3CB185E11EAAC9D7C08B736C1633B42.asc;
    }

    if ($query_string ~* "^((.+&|)op=get(&|&.+&)search=((0x|)(EB4C43523D4D115FC3819DB0B4E73D7875EAECEF|0B33887A90261BBD0770974A93C54FB4E75F996E|7EB84A3614483BB36E0DAB458DC7A31A1E2268F1|3B2445AB428E0BE4BB55D59253728297B1A6C888|B4E73D7875EAECEF|93C54FB4E75F996E|8DC7A31A1E2268F1|53728297B1A6C888)|work@example.org)(&.+|)|(.+&|)search=((0x|)(EB4C43523D4D115FC3819DB0B4E73D7875EAECEF|0B33887A90261BBD0770974A93C54FB4E75F996E|7EB84A3614483BB36E0DAB458DC7A31A1E2268F1|3B2445AB428E0BE4BB55D59253728297B1A6C888|B4E73D7875EAECEF|93C54FB4E75F996E|8DC7A31A1E2268F1|53728297B1A6C888)|work@example.org)(&|&.+&)op=get(&.+|))$") {
        return 301 /EB4C43523D4D115FC3819DB0B4E73D7875EAECEF.asc;
    }

    return 404;
}
```

You can visualise the regex in the `if` condition at [Debuggex](https://www.debuggex.com/). Example:

![Debuggex](assets/debuggex.png)

I used `hkps2nginx.sh` to setup my Nginx server for `hkps`. You can try out my keyserver:

- URL: hkps://keys.duxco.de
- E-Mail: d at "my github username" dot de
- Key ID in `0xlong`: 0x11BE5F68440E0758

## DNS record

You can add the following DNS record for others to better find your keyserver:

```
_hkps._tcp.example.org. 300 IN SRV 1 1 443 keys.example.org.
```

## Other GnuPG repos

https://github.com/duxco?tab=repositories&q=gpg-

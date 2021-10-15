# KISS-like GnuPG keyserver

Following [draft RFC](https://datatracker.ietf.org/doc/html/draft-shaw-openpgp-hkp-00), `nginx.sh` creates the Nginx configuration for hosting your own GnuPG keyserver which allows only for retrieval of public keys (no sks-like sync, no upload, no index, no vindex):

```bash
# print help
bash nginx.sh -h

# I prefer using the same file for wkd and hkps. Sample run:
gpg --export --armor maria.musterfrau@example.org > pubkey.asc
bash nginx.sh -l "pubkey.asc" -r "/var/www/openpgpkey_example/.well-known/openpgpkey/example.org/hu/asdfasdfasdfasdfasdfasdfasdfasdf"
```

You can visualise the regex in the `if` condition at [Debuggex](https://www.debuggex.com/). Example:

![Debuggex](assets/debuggex.png)

# DNS record

You can add the following DNS record for others to find your keyserver:

```
_hkps._tcp.example.org. 300 IN SRV 1 1 443 keys.example.org.
```

# Other GnuPG repos

https://github.com/duxco?tab=repositories&q=gpg-

## Useful Commands

- Format all Shell files: `shfmt -l -w .`
- Create a new user in Gitea: `sudo su - gitea -c 'gitea admin user create --email me@mail.com --admin --password pass --username usr --config /etc/gitea/app.ini'`
- List all iptable rules: `sudo iptables -L --line-numbers` && `sudo iptables -S`
- Delete a iptable rule: `sudo iptables -D INPUT <Number>`
- Block an IP address: `sudo iptables -A INPUT -s 1.0.1.0 -j DROP`
- Open a port: `sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT`

#### Postgresql Administration Command

- Check backup status: `sudo -u postgres pgbackrest info`
- Check if backup is configured properly: `sudo -u postgres pgbackrest check --stanza=main`
- Create a backup: `sudo -u postgres pgbackrest backup --stanza=main --type=full` (other-types: incr,diff)
- Restore with PITR: `bash postgres/restore.sh --type=time "--target=2024-11-04 04:50:00+00" --target-action=promote` (timezone should be UTC)
- Param for full logs in console: `--log-level-console=info`

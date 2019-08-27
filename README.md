# mikrotik-installer
Scripts to install an army of routerboards - works over ssh with minimal interaction required.

## Start with
```bash
curl https://raw.githubusercontent.com/LaKing/mikrotik-installer/master/install-mikrotik.sh > install-mikrotik.sh \
&& bash install-mikrotik.sh
```

You may pass your username@ip-address-or-hostname as argument, if not it will take the default admin@192.168.88.1


Answer questions with yes or no - or leave the default value (capital letter) once all questions are answered, the script will execute the commands - wherby additional parameters might be asked.

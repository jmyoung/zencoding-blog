# SSL Listener configuration defaults

ssl                     on;
ssl_certificate         /etc/letsencrypt/live/yourdomainhere.local/fullchain.pem;
ssl_certificate_key     /etc/letsencrypt/live/yourdomainhere.local/privkey.pem;

ssl_session_timeout     5m;

# Secure cipher set
# Review https://cipherli.st/ for updates etc
ssl_protocols           TLSv1 TLSv1.1 TLSv1.2;
ssl_ciphers             "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";
ssl_prefer_server_ciphers       on;

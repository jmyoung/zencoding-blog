# LetsEncrypt Authenticator Challenge
location ~ ^/\.well-known/acme-challenge/[^/]+$ {
        proxy_pass              http://letsencrypt:80;
        proxy_set_header        Host $host;
        proxy_set_header        X-Forwarded-For $remote_addr;
}

# Favicon - use same as web root
location = /favicon.ico {
        log_not_found off;
        access_log off;
        alias /usr/share/nginx/html/favicon.ico;
}

# Don't log failures to find robots.txt
location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
        rewrite ^/robots\.txt$ /index.php?robots=1 last;
}

# Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
# Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
location ~ /\. {
        deny all;
}

# Deny access to any files with a .php extension in the uploads directory
# Keep logging the requests to parse later (or to pass to firewall utilities such as fail2ban)
location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
}

# This order might seem weird - this is attempted to match last if rules below fail.
# http://wiki.nginx.org/HttpCoreModule
location / {
        try_files $uri $uri/ /index.php?$args;
}

# Add trailing slash to */wp-admin requests.
rewrite /wp-admin$ $scheme://$host$uri/ permanent;

# Rewrite urls for XML Sitemap (Yoast)
rewrite ^/sitemap_index\.xml$ /index.php?sitemap=1 last;
rewrite ^/([^/]+?)-sitemap([0-9]+)?\.xml$ /index.php?sitemap=$1&sitemap_n=$2 last;

# Directives to send expires headers and turn off 404 error logging.
location ~* ^.+\.(ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|rss|atom|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)$ {
       access_log off; log_not_found off; expires max;
}

# Pass all .php files onto a php-fpm/php-fcgi server.
location ~ \.php$ {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        if (!-f $document_root$fastcgi_script_name) {
                return 404;
        }
        # This is a robust solution for path info security issue and works with "cgi.fix_pathinfo = 1" in /etc/php.ini (default)

        include fastcgi_params;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PHP_VALUE "upload_max_filesize=64m
post_max_size=64m";

        # Mitigation for httpoxy as per https://httpoxy.org/
        fastcgi_param HTTP_PROXY "";

        fastcgi_pass wordpress:9000;
}

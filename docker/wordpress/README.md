What is this?
=============

An all-in-one Wordpress setup, fronted by NGINX, using LetsEncrypt to generate SSL certificates, all in Docker containers.  May require some fiddling, but it shouldn't be too much.

How do I customize this?
========================

* Edit `docker-compose.yml` and change the DB password.  Set the same password for the `MYSQL_ROOT_PASSWORD` and `WORDPRESS_DB_PASSWORD` parameters.  
* Edit the command line for the LetsEncrypt container to include your details and the domain names you want.
* Edit the nginx configuration in `nginx/config` to suit your needs.
* Set up the cipher suites properly, the included set should be pretty OK.

Bringing up the container the first time
========================================

The first start likely won't work if you just start it up as-is, because you don't have any SSL certificates to bootstrap from.  That's OK.  Comment out the port 443 listener in `nginx/config/listener.conf`.

* `docker-compose up`
* You should then find your certificates in `./data/letsencrypt/live/yourdomainhere.local/`
* Edit your listener.conf and uncomment the 444 listener.
* `docker-compose restart nginx`
* You should now have your port 443 listener functional.

You can now issue normal `docker-compose down` and `docker-compose up` and so-on as desired, with no ill effects, since you have an SSL certificate that NGINX can use.

Updating the containers
=======================

Wordpress will update automatically, but you can update the container (which also updates PHP FPM) and the other parts with;

```
docker pull wordpress:fpm
docker pull nginx:latest
docker pull mysql:latest
docker pull quay.io/letsencrypt/letsencrypt:latest
docker-compose down
docker-compose up
```

And that's it.  Your containers are now all updated.

Backing up Wordpress
====================

I'd suggest you run the backup external to the containers, in case the containers get compromised.  You can do something like this;

```
docker exec -i wordpress_mysql_1 mysqldump -u root -pyourdatabasepassword --all-databases 2>/dev/null | gzip -c > database-backup.sql.gz
```

You can then safely just tarball up the Wordpress and nginx data directories as well to go with them.

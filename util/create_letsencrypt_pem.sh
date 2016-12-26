#!/bin/bash

DOMAIN="$1"
EMAIL="$2"

if [ -z "$DOMAIN" ]; then
echo "Usage: $(basename $0) <domain> <email>"
exit 11
fi

wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
./certbot-auto certonly --standalone -d $DOMAIN -m $EMAIL -n --agree-tos

cat /etc/letsencrypt/keys/0000_key-certbot.pem >> $DOMAIN.pem
cat /etc/letsencrypt/live/$DOMAIN/cert.pem > $DOMAIN.pem
cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem >> $DOMAIN.pem
mv $DOMAIN.pem ../


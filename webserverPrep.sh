#!/bin/bash
set -e

# Update package list and install nginx and openssl
apt update
apt install -y nginx openssl

# Generate self-signed SSL certificate and key
SSL_DIR="/etc/ssl"
CERT_DIR="$SSL_DIR/certs"
KEY_DIR="$SSL_DIR/private"
CERT_FILE="$CERT_DIR/nginx-selfsigned.crt"
KEY_FILE="$KEY_DIR/nginx-selfsigned.key"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost"

# Generate a strong Diffie-Hellman group
openssl dhparam -out "$CERT_DIR/dhparam.pem" 2048

# Create nginx SSL configuration snippet
cat > /etc/nginx/snippets/self-signed.conf <<EOF
ssl_certificate $CERT_FILE;
ssl_certificate_key $KEY_FILE;
EOF

cat > /etc/nginx/snippets/ssl-params.conf <<'EOF'
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_ciphers "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384";
ssl_ecdh_curve secp384r1;
ssl_session_timeout  10m;
ssl_session_cache shared:SSL:10m;
ssl_stapling on;
ssl_stapling_verify on;
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
EOF

# Set up default server block for HTTPS, redirect HTTP to HTTPS
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;

    server_name _;

    include snippets/self-signed.conf;
    include snippets/ssl-params.conf;

    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# Create a simple landing page
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Welcome to Your Secure nginx Server!</title>
  <style>
    body { background: #101820; color: #fff; font-family: Arial, sans-serif; text-align: center; padding: 10%; }
    h1 { color: #FEE715; }
    p { font-size: 1.3em; }
    .secure { color: #2ecc40; font-weight: bold; }
  </style>
</head>
<body>
  <h1>🚀 Welcome!</h1>
  <p>This nginx server is running with <span class="secure">HTTPS (self-signed cert)</span>.</p>
  <p>If you see this page, nginx is set up correctly.</p>
</body>
</html>
EOF

# Set permissions
chown www-data:www-data /var/www/html/index.html

# Test nginx configuration
nginx -t

# Restart nginx
systemctl restart nginx

echo "nginx is installed with HTTPS and a landing page!"

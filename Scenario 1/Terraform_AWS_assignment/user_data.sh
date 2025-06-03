#!/bin/bash
yum update -y
yum install -y nginx aws-cli
systemctl enable nginx
systemctl start nginx

sudo mkdir -p /tmp/web
sudo cd /tmp/web

aws s3 cp s3://private-web-content-bucket-shweta/index.html ./index.html
aws s3 cp s3://private-web-content-bucket-shweta/style.css ./style.css
aws s3 cp s3://private-web-content-bucket-shweta/script.js ./script.js

cp *.html /usr/share/nginx/html/
cp *.css /usr/share/nginx/html/
cp *.js /usr/share/nginx/html/

sudo systemctl restart nginx
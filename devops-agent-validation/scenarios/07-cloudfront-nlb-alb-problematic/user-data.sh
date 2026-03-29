#!/bin/bash
yum update -y
yum install -y httpd

# 簡単なWebページを作成
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>CloudFront + NLB + ALB + EC2 Test</title>
</head>
<body>
    <h1>Hello from EC2 Instance</h1>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
    <p>Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
    <p>Timestamp: $(date)</p>
</body>
</html>
EOF

# Apacheを起動
systemctl start httpd
systemctl enable httpd
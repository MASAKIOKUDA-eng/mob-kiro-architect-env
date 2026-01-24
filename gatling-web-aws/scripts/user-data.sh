#!/bin/bash
set -e

# システムアップデート
dnf update -y

# Nginxインストール
dnf install -y nginx

# Webコンテンツを配置
cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gatling Web AWS Demo</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 60px;
            max-width: 800px;
            text-align: center;
        }
        
        h1 {
            color: #333;
            font-size: 3em;
            margin-bottom: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .subtitle {
            color: #666;
            font-size: 1.2em;
            margin-bottom: 40px;
        }
        
        .info-box {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 30px;
            margin: 20px 0;
        }
        
        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 15px 0;
            border-bottom: 1px solid #e0e0e0;
        }
        
        .info-item:last-child {
            border-bottom: none;
        }
        
        .label {
            font-weight: bold;
            color: #667eea;
        }
        
        .value {
            color: #333;
            font-family: monospace;
        }
        
        .footer {
            margin-top: 40px;
            color: #999;
            font-size: 0.9em;
        }
        
        .badge {
            display: inline-block;
            padding: 8px 16px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border-radius: 20px;
            font-size: 0.9em;
            margin: 10px 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Gatling Web AWS</h1>
        <p class="subtitle">AWS Infrastructure Demo</p>
        
        <div class="info-box">
            <div class="info-item">
                <span class="label">Server Name:</span>
                <span class="value">${server_name}</span>
            </div>
            <div class="info-item">
                <span class="label">Server Type:</span>
                <span class="value" id="serverType">Loading...</span>
            </div>
            <div class="info-item">
                <span class="label">Hostname:</span>
                <span class="value" id="hostname">Loading...</span>
            </div>
            <div class="info-item">
                <span class="label">Timestamp:</span>
                <span class="value" id="timestamp">Loading...</span>
            </div>
            <div class="info-item">
                <span class="label">Request Count:</span>
                <span class="value" id="requestCount">1</span>
            </div>
        </div>
        
        <div>
            <span class="badge">EC2</span>
            <span class="badge">ALB</span>
            <span class="badge">Nginx</span>
            <span class="badge">Terraform</span>
        </div>
        
        <div class="footer">
            <p>Powered by AWS | Built with Terraform</p>
        </div>
    </div>
    
    <script>
        // サーバー情報を取得して表示
        document.getElementById('timestamp').textContent = new Date().toLocaleString('ja-JP');
        document.getElementById('hostname').textContent = window.location.hostname;
        
        // サーバータイプを判定
        const hostname = window.location.hostname;
        let serverType = 'Unknown';
        
        if (hostname.includes('elb.amazonaws.com')) {
            serverType = 'EC2 + ALB';
        } else if (hostname.includes('compute.amazonaws.com')) {
            serverType = 'EC2 Single Instance';
        } else {
            serverType = 'EC2 Instance';
        }
        
        document.getElementById('serverType').textContent = serverType;
        
        // リクエストカウントをローカルストレージで管理
        let count = parseInt(localStorage.getItem('requestCount') || '0') + 1;
        localStorage.setItem('requestCount', count.toString());
        document.getElementById('requestCount').textContent = count;
    </script>
</body>
</html>
EOF

# Nginxを起動
systemctl enable nginx
systemctl start nginx

# ファイアウォール設定（Amazon Linux 2023ではデフォルトで無効）
# firewall-cmd --permanent --add-service=http
# firewall-cmd --reload

echo "Web server setup completed!"
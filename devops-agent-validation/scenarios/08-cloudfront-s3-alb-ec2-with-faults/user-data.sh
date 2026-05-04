#!/bin/bash
# ============================================================
# SMB Web Service - API Server Setup
# 障害3: ディスク容量肥大化 cronジョブ
# 障害7: CloudWatch Agent 設定ミス（ログパス不一致）
# ============================================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting API server setup ==="
echo "Timestamp: $(date)"

# システムアップデート
dnf update -y

# Node.js インストール
dnf install -y nodejs npm

# CloudWatch Agent インストール
dnf install -y amazon-cloudwatch-agent

# SSM Agent 確認
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# ============================================================
# API アプリケーションのセットアップ
# ============================================================

mkdir -p /opt/api
cd /opt/api

cat > package.json << 'EOF'
{
  "name": "smb-api-server",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

cat > server.js << 'EOF'
const express = require('express');
const fs = require('fs');
const os = require('os');

const app = express();
const PORT = 3000;

// アクセスログ
const accessLog = '/var/log/api/access.log';
const errorLog = '/var/log/api/error.log';

// ログディレクトリ作成
if (!fs.existsSync('/var/log/api')) {
  fs.mkdirSync('/var/log/api', { recursive: true });
}

// ミドルウェア: アクセスログ記録
app.use((req, res, next) => {
  const logEntry = `${new Date().toISOString()} ${req.method} ${req.url} ${req.ip}\n`;
  fs.appendFileSync(accessLog, logEntry);
  next();
});

// ヘルスチェックエンドポイント（/api/health で応答）
// 注意: ALBは /health をチェックするが、このアプリは /api/health で応答する
app.get('/api/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    uptime: process.uptime()
  });
});

// /health は存在しない（障害4の原因）
// app.get('/health', ...) は意図的に未定義

// API エンドポイント
app.get('/api/status', (req, res) => {
  res.json({
    status: 'running',
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'production',
    memory: process.memoryUsage(),
    hostname: os.hostname()
  });
});

app.get('/api/users', (req, res) => {
  res.json({
    users: [
      { id: 1, name: 'User A' },
      { id: 2, name: 'User B' }
    ]
  });
});

// エラーハンドリング
app.use((err, req, res, next) => {
  const errorEntry = `${new Date().toISOString()} ERROR: ${err.message}\n${err.stack}\n`;
  fs.appendFileSync(errorLog, errorEntry);
  res.status(500).json({ error: 'Internal Server Error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
});
EOF

# 依存関係インストール
npm install --production

# systemd サービス作成
cat > /etc/systemd/system/api-server.service << 'EOF'
[Unit]
Description=SMB API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/api
ExecStart=/usr/bin/node /opt/api/server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable api-server
systemctl start api-server

# ============================================================
# 【障害3】ディスク容量肥大化 cronジョブ
# /var/log/dummy-data.log に大量データを書き込み続ける
# ============================================================

cat > /opt/disk-filler.sh << 'SCRIPT'
#!/bin/bash
# このスクリプトは検証用の障害注入です
# 1分ごとに50MBのダミーデータを /var/log に書き込む
dd if=/dev/urandom of=/var/log/dummy-data.log bs=1M count=50 oflag=append conv=notrunc 2>/dev/null
SCRIPT

chmod +x /opt/disk-filler.sh

# cronジョブ登録（1分ごとに実行）
echo "* * * * * root /opt/disk-filler.sh" > /etc/cron.d/disk-filler
chmod 644 /etc/cron.d/disk-filler

# ============================================================
# 【障害7】CloudWatch Agent 設定ミス
# ログファイルパスが間違っている
# 実際: /var/log/api/access.log, /var/log/api/error.log
# 設定: /var/log/app/access.log, /var/log/app/error.log (存在しない)
# ============================================================

cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWCONFIG'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/app/access.log",
            "log_group_name": "/aws/${project_name}/application",
            "log_stream_name": "{instance_id}/access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/app/error.log",
            "log_group_name": "/aws/${project_name}/error",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/${project_name}/application",
            "log_stream_name": "{instance_id}/user-data",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent", "inodes_free"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
CWCONFIG

# CloudWatch Agent 起動
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "=== API server setup completed ==="
echo "Timestamp: $(date)"

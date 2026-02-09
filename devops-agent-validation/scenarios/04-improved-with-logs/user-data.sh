#!/bin/bash
# ============================================
# Improved Server Configuration
# ============================================

set -e

# ログ設定
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting improved server configuration..."

# システムアップデート
echo "Updating system packages..."
dnf update -y

# CloudWatch Agentのインストール
echo "Installing CloudWatch Agent..."
dnf install -y amazon-cloudwatch-agent

# SSM Agentの確認（Amazon Linux 2023にはプリインストール済み）
echo "Verifying SSM Agent..."
systemctl status amazon-ssm-agent || systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Webサーバーのインストール
echo "Installing web server..."
dnf install -y httpd

# CloudWatch Agent設定
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/aws/${project_name}/application",
            "log_stream_name": "{instance_id}/httpd/access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/aws/${project_name}/application",
            "log_stream_name": "{instance_id}/httpd/error",
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
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# CloudWatch Agentの起動
echo "Starting CloudWatch Agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Webコンテンツの作成
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Improved Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background: linear-gradient(135deg, #e6ffe6 0%, #ccffcc 100%);
        }
        .improvement {
            background: #44ff44;
            color: #004400;
            padding: 10px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 5px solid #00aa00;
        }
        h1 {
            color: #006600;
        }
        .section {
            background: white;
            padding: 20px;
            margin: 20px 0;
            border-radius: 10px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .check {
            color: #00aa00;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <h1>✅ Improved Server - Well-Architected</h1>
    
    <div class="section">
        <h2>ネットワーク改善</h2>
        <div class="improvement"><span class="check">✓</span> セキュリティグループ: 最小権限の原則</div>
        <div class="improvement"><span class="check">✓</span> NACL: 正しいエフェメラルポート設定</div>
        <div class="improvement"><span class="check">✓</span> VPCエンドポイント: プライベートアクセス</div>
    </div>
    
    <div class="section">
        <h2>サーバー改善</h2>
        <div class="improvement"><span class="check">✓</span> IAMロール: 認証情報の安全な管理</div>
        <div class="improvement"><span class="check">✓</span> 最新AMI: セキュリティパッチ適用済み</div>
        <div class="improvement"><span class="check">✓</span> SSM Agent: リモート管理可能</div>
        <div class="improvement"><span class="check">✓</span> CloudWatch Agent: 詳細モニタリング</div>
        <div class="improvement"><span class="check">✓</span> 暗号化: ルートボリューム暗号化</div>
    </div>
    
    <div class="section">
        <h2>ストレージ改善</h2>
        <div class="improvement"><span class="check">✓</span> S3: パブリックアクセスブロック有効</div>
        <div class="improvement"><span class="check">✓</span> S3: バージョニング有効</div>
        <div class="improvement"><span class="check">✓</span> S3: 暗号化設定</div>
        <div class="improvement"><span class="check">✓</span> EBS: KMS暗号化</div>
        <div class="improvement"><span class="check">✓</span> AWS Backup: 自動バックアップ</div>
    </div>
    
    <div class="section">
        <h2>Well-Architected 5つの柱</h2>
        <ul>
            <li><strong>運用の優秀性:</strong> SSM, CloudWatch統合</li>
            <li><strong>セキュリティ:</strong> 暗号化, IAMロール, 最小権限</li>
            <li><strong>信頼性:</strong> バックアップ, マルチAZ</li>
            <li><strong>パフォーマンス効率:</strong> 詳細モニタリング</li>
            <li><strong>コスト最適化:</strong> VPCエンドポイント</li>
        </ul>
    </div>
</body>
</html>
HTML

# Webサーバーの起動
echo "Starting web server..."
systemctl start httpd
systemctl enable httpd

# セキュリティ設定
echo "Applying security configurations..."
# SELinuxの設定（必要に応じて）
# firewalldの設定（Amazon Linux 2023ではデフォルトで無効）

# 完了ログ
echo "Improved server configuration completed successfully!"
echo "Timestamp: $(date)"
echo "Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)"
echo "IAM Role: $(ec2-metadata --iam-info | cut -d ' ' -f 2)"

# ステータスファイルの作成
cat > /var/www/html/status.json << EOF
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "instance_id": "$(ec2-metadata --instance-id | cut -d ' ' -f 2)",
  "improvements": [
    "iam-role-configured",
    "latest-ami",
    "ssm-agent-enabled",
    "cloudwatch-agent-enabled",
    "encryption-enabled",
    "vpc-endpoints-configured",
    "backup-enabled"
  ]
}
EOF

echo "User data script completed successfully!"
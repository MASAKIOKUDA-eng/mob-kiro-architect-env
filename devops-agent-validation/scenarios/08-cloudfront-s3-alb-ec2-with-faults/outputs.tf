output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.api.dns_name
}

output "s3_bucket_name" {
  description = "S3 static content bucket name"
  value       = aws_s3_bucket.static.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.api.name
}

output "log_groups" {
  description = "CloudWatch Log Group names"
  value = {
    application = aws_cloudwatch_log_group.application.name
    access      = aws_cloudwatch_log_group.access.name
    error       = aws_cloudwatch_log_group.error.name
    vpc_flow    = aws_cloudwatch_log_group.vpc_flow.name
  }
}

output "alarms" {
  description = "CloudWatch Alarm names"
  value = {
    unhealthy_hosts  = aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name
    alb_5xx          = aws_cloudwatch_metric_alarm.alb_5xx.alarm_name
    cloudfront_4xx   = aws_cloudwatch_metric_alarm.cloudfront_4xx.alarm_name
    response_time    = aws_cloudwatch_metric_alarm.response_time.alarm_name
    no_logs          = aws_cloudwatch_metric_alarm.no_logs.alarm_name
    rejected_traffic = aws_cloudwatch_metric_alarm.rejected_traffic.alarm_name
  }
}

output "fault_summary" {
  description = "注入されている障害の一覧"
  value = <<-EOT
    ============================================================
    注入されている障害（8つ）
    ============================================================
    
    [ネットワーク・接続性]
    1. ALB SGのegressにエフェメラルポート未許可 → ヘルスチェック応答不可
    2. EC2 SGのegressでHTTP(80)未許可 → 外部API/yum失敗
    
    [アプリケーション・サーバー]
    3. ディスク容量肥大化cronジョブ → ログ書き込み失敗
    4. ALBヘルスチェックパス不一致 (/health vs /api/health)
    
    [CDN・静的コンテンツ]
    5. S3バケットポリシーで/assets/*へのアクセス拒否 → CSS/JS 403
    6. CloudFront TTL 86400秒 → デプロイ反映遅延
    
    [監視・運用]
    7. CloudWatch Agent設定ミス（ログパス不一致） → ログ未収集
    8. Auto Scaling クールダウン600秒 → スケールアウト遅延
  EOT
}

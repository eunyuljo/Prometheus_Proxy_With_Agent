#!/bin/bash

# Update system
yum update -y


#### Prometheus, Alertmanager 설치

# 디렉토리 생성
mkdir -p /mzc/monitoring/{prometheus,alertmanager}  
mkdir -p /mzc/database/{prometheus,alertmanager}

# 바이너리 파일 다운로드
curl -L https://github.com/prometheus/prometheus/releases/download/v2.53.3/prometheus-2.53.3.linux-amd64.tar.gz -o /mzc/monitoring/prometheus/prometheus.tar.gz
curl -L https://github.com/prometheus/alertmanager/releases/download/v0.28.0/alertmanager-0.28.0.linux-amd64.tar.gz -o /mzc/monitoring/alertmanager/alertmanager.tar.gz

# 파일 unzip
tar -xvf /mzc/monitoring/prometheus/prometheus.tar.gz -C /mzc/monitoring/prometheus --strip-components=1
tar -xvf /mzc/monitoring/alertmanager/alertmanager.tar.gz -C /mzc/monitoring/alertmanager --strip-components=1

# 압축 원본 삭제
rm -rf /mzc/monitoring/prometheus/prometheus.tar.gz
rm -rf /mzc/monitoring/alertmanager/alertmanager.tar.gz

# systemctl 프로그램 등록
cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=root
Group=root
Type=simple
ExecStart=/mzc/monitoring/prometheus/prometheus --config.file=/mzc/monitoring/prometheus/prometheus.yml --web.enable-lifecycle --storage.tsdb.retention.time=8760h --storage.tsdb.path=/mzc/database/prometheus
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=prometheus
[Install]
WantedBy=multi-user.target
EOF

# systemctl 프로그램 등록
cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target
[Service]
User=root
Group=root
Type=simple
ExecStart=/mzc/monitoring/alertmanager/alertmanager --config.file=/mzc/monitoring/alertmanager/alertmanager.yml --storage.path=/mzc/database/alertmanager
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=alertmanager
[Install]
WantedBy=multi-user.target
EOF

# 응용프로그램 시작 및 시작 프로그램 등록
systemctl daemon-reload


systemctl start prometheus
systemctl start alertmanager
systemctl enable prometheus
systemctl enable alertmanager

# Install netstat for port checking
yum install -y net-tools

# Log installation completion
# Prometheus 설정 파일 생성 (Proxy Agent 메트릭 수집 포함)
cat <<EOF > /mzc/monitoring/prometheus/prometheus.yml
# my global config
global:
  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
  # scrape_timeout is set to the global default (10s).

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

# A scrape configuration containing exactly one endpoint to scrape:
# Here it's Prometheus itself.
scrape_configs:
  # The job name is added as a label job=<job_name> to any timeseries scraped from this config.
  - job_name: "prometheus"
    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
    static_configs:
      - targets: ["localhost:9090"]

  # Proxy Agent 메트릭 수집
  - job_name: "proxy-agent-metrics"
    static_configs:
      - targets: ["localhost:8080"]
    metrics_path: "/eyjo-test-proxy-agent-ne"
    scrape_interval: 10s

  # Private Instance 메트릭 수집
  - job_name: "private-instance-metrics"
    static_configs:
      - targets: ["localhost:8080"]
    metrics_path: "/private-instance-node-exporter"
    scrape_interval: 10s
EOF

echo "Prometheus and Alertmanager installation completed" >> /var/log/user-data.log
echo "Checking ports:" >> /var/log/user-data.log
netstat -ntpl | egrep "9090|9093" >> /var/log/user-data.log



###### Prometheus-Proxy 설치

# java 11 이상 설치 필요 - java 17 설치
dnf install -y java-17-amazon-corretto-devel 

mkdir -p /mzc/monitoring/prometheus-proxy
wget https://github.com/pambrose/prometheus-proxy/releases/download/1.23.2/prometheus-proxy.jar -P /mzc/monitoring/prometheus-proxy

# systemctl 프로그램 등록 (prometheus-proxy)
cat <<EOF > /etc/systemd/system/prometheus-proxy.service
[Unit]
Description=Prometheus Proxy
Wants=network-online.target
After=network-online.target prometheus.service
[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/bin/java -jar /mzc/monitoring/prometheus-proxy/prometheus-proxy.jar
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=prometheus-proxy
[Install]
WantedBy=multi-user.target
EOF

# 응용프로그램 시작 및 시작 프로그램 등록
systemctl daemon-reload
systemctl start prometheus-proxy
systemctl enable prometheus-proxy

echo "Prometheus-Proxy installation completed" >> /var/log/user-data.log
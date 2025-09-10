#!/bin/bash

# Update system
yum update -y

###### Node Exporter 설치

# 디렉터리 생성
mkdir -p /mzc/monitoring/node-exporter

# 바이너리 파일 다운로드
curl -L https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz -o /mzc/monitoring/node-exporter/node-exporter.tar.gz

# 파일 unzip
tar -xvf /mzc/monitoring/node-exporter/node-exporter.tar.gz -C /mzc/monitoring/node-exporter --strip-components=1

# 압축 원본 삭제
rm -rf /mzc/monitoring/node-exporter/node-exporter.tar.gz

# 서비스 등록 (node_exporter)
cat <<EOF > /usr/lib/systemd/system/node_exporter.service
[Unit]
Description=NodeExporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Type=simple
ExecStart=/mzc/monitoring/node-exporter/node_exporter
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# daemon reload
systemctl daemon-reload

# 서비스 시작
systemctl start node_exporter
systemctl enable node_exporter

# Install netstat for port checking
yum install -y net-tools

# Log installation completion
echo "Node Exporter installation completed" >> /var/log/user-data.log
echo "Checking node_exporter port:" >> /var/log/user-data.log
netstat -ntpl | grep "9100" >> /var/log/user-data.log
echo "Testing node_exporter endpoint:" >> /var/log/user-data.log
curl -s localhost:9100/metrics | head -10 >> /var/log/user-data.log
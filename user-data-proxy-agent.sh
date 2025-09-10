#!/bin/bash

# Update system
yum update -y

###### Prometheus Proxy Agent 설치

# Java 17 설치
dnf install -y java-17-amazon-corretto-devel 

# 폴더 생성
mkdir -p /mzc/monitoring/prometheus-proxy-agent

# proxy 관련 jar 파일 다운로드
wget https://github.com/pambrose/prometheus-proxy/releases/download/1.23.2/prometheus-agent.jar -P /mzc/monitoring/prometheus-proxy-agent

# agent.conf 파일 생성
cat <<EOF > /mzc/monitoring/prometheus-proxy-agent/agent.conf
agent {
  pathConfigs: [
    {
      name: "eyjo-test-proxy-agent-ne"
      path: "eyjo-test-proxy-agent-ne"
      url: "http://127.0.0.1:9100/metrics"
    },
    {
      name: "private-instance-node-exporter"
      path: "private-instance-node-exporter"
      url: "http://PRIVATE_INSTANCE_IP:9100/metrics"
    }
  ]
}
EOF

# systemctl 프로그램 등록 (prometheus-proxy-agent)
cat <<EOF > /etc/systemd/system/prometheus-proxy-agent.service
[Unit]
Description=Prometheus Proxy Agent
Wants=network-online.target
After=network-online.target
[Service]
User=root
Group=root
Type=simple
WorkingDirectory=/mzc/monitoring/prometheus-proxy-agent
ExecStart=/usr/bin/java -jar /mzc/monitoring/prometheus-proxy-agent/prometheus-agent.jar --config /mzc/monitoring/prometheus-proxy-agent/agent.conf --proxy PROMETHEUS_PROXY_IP:50051
Restart=always
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=prometheus-proxy-agent
[Install]
WantedBy=multi-user.target
EOF

# prometheus proxy IP를 실제 EIP로 치환 (템플릿에서 처리됨)
sed -i 's/PROMETHEUS_PROXY_IP/${prometheus_proxy_ip}/g' /etc/systemd/system/prometheus-proxy-agent.service

# private instance IP를 실제 IP로 치환
sed -i 's/PRIVATE_INSTANCE_IP/${private_instance_ip}/g' /mzc/monitoring/prometheus-proxy-agent/agent.conf

# 응용프로그램 시작 및 시작 프로그램 등록
systemctl daemon-reload
systemctl start prometheus-proxy-agent
systemctl enable prometheus-proxy-agent

echo "Prometheus Proxy Agent installation completed" >> /var/log/user-data.log
echo "Checking prometheus processes:" >> /var/log/user-data.log
ps -ef | grep prometheus >> /var/log/user-data.log


###### Node Exporter 설치 (Proxy Agent 자체 모니터링용)

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

echo "Node Exporter installation completed" >> /var/log/user-data.log
echo "Checking node_exporter port:" >> /var/log/user-data.log
netstat -ntpl | grep "9100" >> /var/log/user-data.log
echo "Testing node_exporter endpoint:" >> /var/log/user-data.log
curl -s localhost:9100/metrics | head -10 >> /var/log/user-data.log
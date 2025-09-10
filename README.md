# Prometheus Proxy with Terraform

AWS에서 Prometheus Proxy를 사용한 멀티 VPC 모니터링 시스템을 구축하는 Terraform 프로젝트입니다.

## 📋 개요

이 프로젝트는 두 개의 VPC에 걸쳐 Prometheus 모니터링 시스템을 구축합니다:
- **VPC 1**: Prometheus Server + Prometheus Proxy 
- **VPC 2**: Prometheus Proxy Agent + 모니터링 대상 서버들

## 🏗️ 아키텍처

```
┌─────────────────────────────────────┐    ┌─────────────────────────────────────┐
│               VPC 1                 │    │               VPC 2                 │
│         (10.0.0.0/16)               │    │         (10.1.0.0/16)               │
├─────────────────────────────────────┤    ├─────────────────────────────────────┤
│  Public Subnet (ap-northeast-2a)    │    │  Public Subnet (ap-northeast-2a)    │
│  ┌─────────────────────────────────┐│    │  ┌─────────────────────────────────┐│
│  │    Prometheus Server            ││    │  │   Prometheus Proxy Agent        ││
│  │  - Prometheus (9090)            ││    │  │  - Collects metrics             ││
│  │  - Alertmanager (9093)          ││◄──►│  │  - Sends via gRPC (50051)       ││
│  │  - Prometheus Proxy (8080)      ││    │  │  - Node Exporter (9100)         ││
│  │  - Node Exporter (9100)         ││    │  └─────────────────────────────────┘│
│  │  - Blackbox Exporter (9115)     ││    │                                     │
│  └─────────────────────────────────┘│    │  Private Subnet (ap-northeast-2a)   │
│                                     │    │  ┌─────────────────────────────────┐│
│                                     │    │  │    Private Instance             ││
│                                     │    │  │  - Node Exporter (9100)         ││
│                                     │    │  │  - Monitored via SSM            ││
│                                     │    │  └─────────────────────────────────┘│
└─────────────────────────────────────┘    └─────────────────────────────────────┘
```

## 🚀 배포 방법

### 1. 사전 요구사항

- AWS CLI 구성
- Terraform >= 1.0
- 적절한 AWS IAM 권한

### 2. 배포 실행

```bash
# 저장소 클론
git clone <repository-url>

# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 배포 실행
terraform apply
```

### 3. 접속 정보 확인

배포 완료 후 출력되는 정보:
```bash
# Prometheus 서버 접속 정보
prometheus_instance_info = {
  elastic_ip = "xxx.xxx.xxx.xxx"
  # ...
}

# Proxy Agent 정보
prometheus_proxy_agent_info = {
  elastic_ip = "yyy.yyy.yyy.yyy"
  # ...
}
```

## 🌐 서비스 접속

| 서비스 | URL | 포트 | 설명 |
|--------|-----|------|------|
| Prometheus | `http://<prometheus-eip>:9090` | 9090 | 메트릭 조회 및 쿼리 |
| Alertmanager | `http://<prometheus-eip>:9093` | 9093 | 알림 관리 |
| Prometheus Proxy | `http://<prometheus-eip>:8080` | 8080 | Proxy 관리 API |
| Blackbox Exporter | `http://<prometheus-eip>:9115` | 9115 | 외부 엔드포인트 모니터링 |

## 📊 메트릭 수집 경로

### 1. 직접 수집 (VPC 1)
- **prometheus**: Prometheus 자체 메트릭 (9090/metrics)
- **Blackbox Exporter**: 외부 엔드포인트 모니터링 (9115/metrics)

### 2. Proxy를 통한 자동 수집 (VPC 2)
Prometheus가 다음 job으로 자동 수집합니다:

```yaml
# prometheus.yml에 자동 설정됨
scrape_configs:
  - job_name: "proxy-agent-metrics"
    static_configs:
      - targets: ["localhost:8080"]
    metrics_path: "/eyjo-test-proxy-agent-ne"
    scrape_interval: 10s

  - job_name: "private-instance-metrics"  
    static_configs:
      - targets: ["localhost:8080"]
    metrics_path: "/private-instance-node-exporter"
    scrape_interval: 10s
```

### 3. 수동 확인 방법
```bash
# Proxy Agent 자체 Node Exporter
curl http://<prometheus-eip>:8080/eyjo-test-proxy-agent-ne

# Private Instance Node Exporter
curl http://<prometheus-eip>:8080/private-instance-node-exporter
```

## 🔧 설정 파일

### User Data 스크립트
- `user-data-prometheus.sh`: Prometheus, Alertmanager, Prometheus Proxy 설치
- `user-data-proxy-agent.sh`: Prometheus Proxy Agent 설치
- `user-data-node-exporter.sh`: Node Exporter 설치

### 주요 설정
- **Prometheus 설정**: `/mzc/monitoring/prometheus/prometheus.yml` (자동 생성됨)
- **Agent 설정**: `/mzc/monitoring/prometheus-proxy-agent/agent.conf` (자동 생성됨)

### 자동 생성되는 설정들
- Prometheus는 배포 시 모든 Proxy Agent 메트릭을 수집하도록 자동 설정
- Agent는 자체 Node Exporter + Private Instance Node Exporter 수집 설정

## 🛠️ 리소스 구성

### VPC 1 (Prometheus Server)
- **EC2**: t3.medium, Amazon Linux 2023
- **서비스**: Prometheus, Alertmanager, Prometheus Proxy, Blackbox Exporter
- **네트워크**: Public subnet, EIP 할당

### VPC 2 (Monitoring Targets)
- **Proxy Agent**: t3.medium, Public subnet, EIP 할당, Node Exporter 포함
- **Private Instance**: t3.medium, Private subnet, SSM 접근만, Node Exporter 포함

### 보안 그룹
- **Prometheus**: 22, 80, 443, 9090, 9093, 8080, 50051, 9115
- **Proxy Agent**: 22, 80, 443, 9100
- **Private Instance**: 22, 9100 (VPC 내부만)

## 🔒 보안 설정

- **SSM 접근**: 모든 인스턴스에 SSM 역할 부여
- **Private Instance**: 인터넷 접근 불가, SSM을 통해서만 관리
- **방화벽**: 필요한 포트만 선택적 개방

## 📝 사용자 가이드

### 메트릭 확인
```bash
# Prometheus에서 모든 타겟 확인
curl http://<prometheus-eip>:9090/api/v1/targets

# 자동 수집되는 job들 확인
curl 'http://<prometheus-eip>:9090/api/v1/query?query=up{job="proxy-agent-metrics"}'
curl 'http://<prometheus-eip>:9090/api/v1/query?query=up{job="private-instance-metrics"}'

# Node Exporter 메트릭 확인
curl 'http://<prometheus-eip>:9090/api/v1/query?query=node_uname_info'
```

### 서비스 상태 확인
```bash
# SSM으로 서버 접속
aws ssm start-session --target <instance-id>

# 서비스 상태 확인
sudo systemctl status prometheus
sudo systemctl status prometheus-proxy-agent
sudo systemctl status node_exporter
```

### 로그 확인
```bash
# 설치 로그
tail -f /var/log/user-data.log

# 서비스 로그
sudo journalctl -u prometheus -f
sudo journalctl -u prometheus-proxy-agent -f
```

## 🗂️ 파일 구조

```
├── main.tf                           # VPC 및 기본 인프라
├── ec2.tf                           # EC2 인스턴스 및 보안 그룹
├── variables.tf                     # 입력 변수
├── outputs.tf                       # 출력 값
├── user-data-prometheus.sh          # Prometheus 서버 설치 스크립트
├── user-data-proxy-agent.sh         # Proxy Agent 설치 스크립트
├── user-data-node-exporter.sh       # Node Exporter 설치 스크립트
├── .gitignore                       # Git 제외 파일
└── README.md                        # 프로젝트 문서
```

## 🔄 업데이트 및 유지보수

### User Data 재적용
```bash
# 특정 인스턴스 재생성
terraform destroy -target=aws_instance.prometheus_server
terraform apply

# 또는 수동 스크립트 실행
sudo bash /var/lib/cloud/instances/$(cat /var/lib/cloud/data/instance-id)/user-data.txt
```

### 설정 변경
```bash
# Prometheus 설정 리로드
curl -X POST http://<prometheus-eip>:9090/-/reload

# Proxy Agent 재시작
sudo systemctl restart prometheus-proxy-agent
```

## 🐛 문제 해결

### 일반적인 문제들

1. **Agent가 연결되지 않는 경우**
   - 50051 포트가 열려있는지 확인
   - gRPC 연결 상태 확인

2. **메트릭이 수집되지 않는 경우**
   - Node Exporter 서비스 상태 확인
   - 네트워크 연결성 확인

3. **SSM 접근이 안되는 경우**
   - NAT Gateway 활성화 확인
   - IAM 역할 권한 확인

## 📞 지원

문제가 발생하거나 개선 사항이 있으면 이슈를 등록해주세요.

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.
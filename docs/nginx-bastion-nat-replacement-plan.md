# Doktori Dev Infra Plan (ALB/NATGW 대체안)

## 1) 목표
- `ALB`를 사용하지 않고 `Nginx Reverse Proxy`로 대체
- `NAT Gateway`를 사용하지 않고 `Bastion`을 `NAT Instance` 역할까지 겸임
- FE(Next.js SSR) 서버는 `private subnet`에 배치
- CloudFront + S3 정적 오리진 구조는 유지

## 2) 아키텍처(대체안)
- Public Subnet A
  - `Bastion+NAT EC2` (SSH 진입점 + private outbound NAT)
  - `Nginx EC2` (CloudFront SSR 오리진)
- Private Subnet A/B
  - `FE EC2`(Next.js SSR, 포트 `3000`)
- S3
  - `/_next/static/*`, `public/*` 정적 파일
- CloudFront
  - `/_next/static/*` -> S3
  - `/*` -> `Nginx` 오리진

## 3) 리스크(반드시 인지)
- 단일 AZ/단일 인스턴스 장애 시 서비스 영향이 큼
- `Bastion+NAT` 겸용은 보안/운영 리스크 증가
- `ALB` 미사용으로 매니지드 헬스체크/자동복구/인증서 연동 편의성 감소

개발/스테이징 용도로는 가능하지만, 운영 전환 시 `ALB + NAT Gateway` 복귀 권장.

## 4) Terraform 디렉토리 계획
- `infra/network`
  - VPC, Subnet, IGW, Route Table
- `infra/security`
  - SG
- `infra/compute`
  - Bastion+NAT EC2, Nginx EC2, FE EC2, Private RT 기본 라우트(NAT ENI)
- `infra/cdn`
  - 기존 CloudFront+S3 유지, `ssr_origin_domain`만 nginx 도메인으로 변경

## 4-1) 테스트 기본 스펙 고정
- 모든 EC2 인스턴스 타입: `t3.micro`
- 대상:
  - `Bastion+NAT EC2`
  - `Nginx EC2`
  - `FE EC2`

## 5) 구현 단계 (A-Z)
### A. 네트워크
1. VPC: `10.0.0.0/16`
2. Public Subnet: `10.0.1.0/24`
3. Private Subnet A/B: `10.0.11.0/24`, `10.0.12.0/24`
4. IGW 연결
5. Public RT: `0.0.0.0/0 -> IGW`
6. Private RT 생성(기본 라우트는 compute 단계에서 NAT ENI로 추가)

### B. Bastion + NAT Instance
1. EC2 생성(public subnet, EIP 미사용, instance type `t3.micro`)
2. `source_dest_check = false` 설정
3. 커널 포워딩/iptables 설정
4. 재부팅 후 iptables rules 유지 설정

예시 user-data 핵심:
```bash
#!/bin/bash
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i eth0 -o eth0 -j ACCEPT
```

### C. Nginx Reverse Proxy 서버
1. EC2 생성(public subnet, instance type `t3.micro`)
2. SG: `80/443`은 CloudFront CIDR 또는 전체(개발용)에서 허용
3. Nginx 설치 후 `localhost:3000`이 아닌 private FE 내부 DNS:3000으로 프록시

예시 설정:
```nginx
server {
  listen 80;
  server_name _;

  location / {
    proxy_pass http://fe-private.internal:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

### D. FE(Private) 서버
1. EC2 생성(private subnet, instance type `t3.micro`)
2. 앱 포트 `3000` 오픈 대상: `Nginx SG`만 허용
3. SSH(22) 허용 대상: `Bastion SG`만 허용
4. FE 배포 후 `curl localhost:3000` 정상 확인

### E. 보안그룹 정책
- `sg_bastion_nat`
  - Inbound `22`: 임시 접근 필요 시에만 최소 범위 허용
  - Outbound: all
- `sg_nginx`
  - Inbound `80/443`: CloudFront 접근 대역(또는 임시 all)
  - Outbound `3000`: `sg_fe`
- `sg_fe`
  - Inbound `3000`: `sg_nginx`
  - Inbound `22`: `sg_bastion_nat`
  - Outbound: all(인터넷은 NAT 경유)

### F. CloudFront 연결
1. `infra/cdn/terraform.tfvars` 수정
2. `ssr_origin_domain = "<nginx public dns>"` (프로토콜/슬래시 없이)
3. 필요 시 `ssr_origin_protocol_policy = "http-only"`로 임시 운영

### G. 배포 순서
1. `terraform -chdir=infra/network init && terraform -chdir=infra/network apply`
2. `terraform -chdir=infra/security init && terraform -chdir=infra/security apply`
3. `terraform -chdir=infra/compute init && terraform -chdir=infra/compute apply`
4. `terraform -chdir=infra/cdn plan && terraform -chdir=infra/cdn apply`

## 5-1) 현재 진행 상태
- 완료:
  - `infra/network` apply 완료
  - `infra/security` apply 완료
- 미진행:
  - `infra/compute`
  - `infra/cdn`

### H. 검증 체크리스트
1. Bastion 접속 가능(SSH)
2. FE 서버가 NAT 통해 외부 패키지 설치 가능
3. Nginx에서 FE private IP로 프록시 가능
4. CloudFront `/*` 요청이 Nginx -> FE로 정상 응답
5. CloudFront `/_next/static/*` 요청이 S3에서 정상 응답

### I. 장애/롤백
1. Nginx 장애 시 SSR 전체 영향
2. Bastion+NAT 장애 시 private outbound 중단
3. 빠른 복구를 위해 AMI/Launch Template 유지
4. 운영 이전에 `ALB + NAT Gateway`로 단계적 복귀 계획 준비

## 6) 즉시 실행 TODO
1. `infra/compute`에 network/security output 값 주입 후 `plan -> apply`
2. `Bastion+NAT` user-data 및 private 기본 라우트 동작 확인
3. `Nginx -> FE private` 연결 확인
4. `infra/cdn`의 `ssr_origin_domain`을 nginx 도메인으로 교체 후 `plan -> apply`

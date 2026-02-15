# Infra Diagram

```text
[사용자 브라우저]
      |
      v
[CloudFront]  ──────────────────────────────────────────────┐
   |                                                        |
   | (정적 파일: /_next/static/*)                           | (SSR/기타: /*)
   v                                                        v
[S3 정적 버킷]                                         [Nginx EC2 (Public Subnet)]
                                                            |
                                                            v
                                                  [FE EC2 (Next.js) (Private Subnet)]
                                                            |
                                                            | (아웃바운드 인터넷 필요할 때)
                                                            v
                                                [Bastion + NAT EC2 (Public Subnet)]
                                                            |
                                                            v
                                                   [IGW (Internet Gateway)]
                                                            |
                                                            v
                                                       [Internet]
```

## 현재 적용 상태 요약

### 1) 실제 리소스
- VPC: `vpc-0748ee7da6c386861`
- Public Subnet: `subnet-0a4f71ff33428690d`
- Private Subnet A/B: `subnet-047324ec024aefc25`, `subnet-0d2d0fd602e522a37`
- Bastion+NAT: `i-00fbfcdfb106037d2` (`54.180.151.216`)
- Nginx: `i-08ff154c333e80490` (`43.201.51.112`)
- FE: `i-0d5c31c492e4bc9eb` (`10.0.11.228`)
- FE IAM Profile: `doktori-fe-ec2-profile`
- FE IAM Role: `doktori-fe-ec2-role`
- CloudFront: `E3T1SF1FP2TR` (`d1xf7hpa4b4zbr.cloudfront.net`)
- S3 Static Bucket: `doktori-fe-static-246477585940-dev`

### 2) 라우팅/오리진 검증 결과
- Private RT `rtb-043cc010d8de82d4d`:
  - `0.0.0.0/0 -> eni-07aac1602bff0d98a` (Bastion NAT ENI)
- CloudFront 오리진:
  - 정적: S3 버킷 오리진
  - SSR: `ec2-43-201-51-112.ap-northeast-2.compute.amazonaws.com` (`http-only`)

### 3) 현재 동작 상태
- `CloudFront -> Nginx`: 정상 응답 (`HTTP 200`)
- `Nginx -> FE:3000`: 현재 연결 실패 (FE 앱 미기동 상태)
- `FE -> SSM`: Online 등록 확인
- 결과적으로 `/` 요청은 FE 응답이 아니라 Nginx 기본 페이지 응답

## 다음 작업
1. FE 서버에서 애플리케이션(`:3000`) 기동
2. Nginx `proxy_pass`를 FE(`10.0.11.228:3000`)로 확정
3. CloudFront 경유 `/` 응답이 FE에서 오는지 재검증

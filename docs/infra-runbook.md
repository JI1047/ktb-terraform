# Doktori Infra Runbook (Single Source)

## 1) 목적
- 이 문서 하나로 현재 테스트 인프라 상태, 오늘 작업 이력, 내일 실행 계획, 운영 명령어를 모두 확인한다.
- 범위:
  - Terraform: `infra/network`, `infra/security`, `infra/iam`, `infra/compute`, `infra/cdn`
  - 운영 자동화: `ansible/*`
  - CI/CD 연동: GitHub OIDC Role, S3/CloudFront/ECR/SSM

## 2) 현재 리소스 상태 (2026-02-15 기준)
- VPC: `vpc-0748ee7da6c386861`
- Public Subnet: `subnet-0a4f71ff33428690d`
- Private Subnet A/B: `subnet-047324ec024aefc25`, `subnet-0d2d0fd602e522a37`
- Bastion+NAT:
  - Instance: `i-00fbfcdfb106037d2`
  - DNS: `ec2-54-180-151-216.ap-northeast-2.compute.amazonaws.com`
  - IP: `54.180.151.216`
- Nginx:
  - Instance: `i-08ff154c333e80490`
  - DNS: `ec2-43-201-51-112.ap-northeast-2.compute.amazonaws.com`
  - IP: `43.201.51.112`
- FE:
  - Instance: `i-0d5c31c492e4bc9eb`
  - Private IP: `10.0.11.228`
- IAM (FE):
  - Role: `doktori-fe-ec2-role`
  - Instance Profile: `doktori-fe-ec2-profile`
  - Policies: `AmazonSSMManagedInstanceCore`, `AmazonEC2ContainerRegistryReadOnly`
- CDN:
  - CloudFront ID: `E3T1SF1FP2TR`
  - Domain: `d1xf7hpa4b4zbr.cloudfront.net`
- Static Bucket: `doktori-fe-static-246477585940-dev`

## 3) 현재 동작 상태
- `CloudFront -> Nginx -> FE` 경로는 연결 완료.
- FE Docker 컨테이너 실행 확인:
  - `frontend`
  - `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com/fe-test:sha-c20a1f3`
- SSM 상태:
  - FE `i-0d5c31c492e4bc9eb` = `Online`
- 남은 이슈:
  - 브라우저 JS/CSS 로드 오류 일부 존재
  - 원인: SSR 이미지 버전과 S3 정적 파일 해시 불일치 가능성 높음

## 4) 오늘 반영된 핵심 변경
### 4-1) 인프라
- Ubuntu 전환 (compute)
- CloudFront SSR 오리진 교체
- `infra/iam` 신규 생성 (FE용 Role/Profile)
- FE에 Instance Profile in-place 연결

### 4-2) 운영 자동화
- Ansible 인벤토리/유저 Ubuntu 기준 정리
- `bootstrap.yml`, `fe.yml`, `nginx.yml`를 `apt` 기준으로 정리
- FE에 Docker/AWS CLI/SSM Agent 적용

### 4-3) OIDC/권한
- `GitHubActions-Deploy-Role` trust policy에 `JI1047/5-team-service-fe` 브랜치 허용 추가
- Deploy inline policy(`doktori-gha-deploy-permissions`) 추가:
  - ECR push/pull
  - S3 static sync
  - `ssm:SendCommand`, `ssm:ListCommandInvocations`, `ssm:GetCommandInvocation`
  - `ec2:DescribeInstances`
- SSM 문서 ARN 수정:
  - `arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript`

## 5) CI/CD 필수 값
- `AWS_DEPLOY_ROLE_ARN`: `arn:aws:iam::246477585940:role/GitHubActions-Deploy-Role`
- `S3_STATIC_BUCKET_DEV`: `doktori-fe-static-246477585940-dev`
- `S3_STATIC_BUCKET_PROD`: `doktori-fe-static-246477585940-dev` (테스트 동일값)
- `CLOUDFRONT_DISTRIBUTION_ID_DEV`: `E3T1SF1FP2TR`
- `CLOUDFRONT_DISTRIBUTION_ID_PROD`: `E3T1SF1FP2TR` (테스트 동일값)
- ECR:
  - Registry: `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com`
  - Repository URI: `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com/fe-test`

## 6) 내일 바로 실행할 순서
1. 팀 합의(네이밍/권한/배포 방식) 확정
2. 워크플로우 최종본 1개로 통일 (SSM/SSH 혼용 제거)
3. 정적/동적 버전 정합성 복구
- 동일 SHA로 FE 이미지 재배포
- 동일 SHA로 `.next/static`, `public` S3 재업로드
- CloudFront invalidation (`/_next/static/*`, `/public/*`, `/`)
4. SSM 타깃 전략 확정
- 태그 기반 계속 사용 시 FE 태그 추가 필요:
  - `Environment=dev`
  - `Service=frontend`
- 또는 인스턴스 ID 직접 지정으로 단순화
5. 최종 검증
- CloudFront 페이지 렌더 정상
- 네트워크 탭 JS/CSS 오류 0
- FE 컨테이너 Up
- SSM Online 유지

## 7) 운영 명령어 모음
### 7-1) SSH
```bash
# local -> bastion
ssh -i infra/compute/keys/doktori-fe-key.pem ubuntu@ec2-54-180-151-216.ap-northeast-2.compute.amazonaws.com

# bastion -> fe
ssh -i ~/doktori-fe-key.pem ubuntu@10.0.11.228
```

### 7-2) SSM 확인
```bash
aws ssm describe-instance-information \
  --filters Key=InstanceIds,Values=i-0d5c31c492e4bc9eb \
  --query "InstanceInformationList[].{InstanceId:InstanceId,PingStatus:PingStatus,Platform:PlatformName}" \
  --output table
```

### 7-3) 정적 파일 확인
```bash
aws s3 ls s3://doktori-fe-static-246477585940-dev/_next/static/ --recursive | head
aws s3 ls s3://doktori-fe-static-246477585940-dev/public/ --recursive | head
```

### 7-4) CloudFront 확인
```bash
curl -I https://d1xf7hpa4b4zbr.cloudfront.net/
```

## 8) 테스트 환경 전체 삭제 순서 (필요 시)
1. `terraform -chdir=infra/cdn destroy -auto-approve`
2. `terraform -chdir=infra/compute destroy -auto-approve`
3. `terraform -chdir=infra/iam destroy -auto-approve`
4. `terraform -chdir=infra/security destroy -auto-approve`
5. `terraform -chdir=infra/network destroy -auto-approve`

## 9) 참고 문서
- 아키텍처 그림: `docs/current-architecture-diagram.md`
- 텍스트 다이어그램: `docs/diagram.md`

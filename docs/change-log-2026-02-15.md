# Doktori Infra 상세 변경 이력 (2026-02-15)

## 1) 범위
- 본 문서는 테스트 환경에서 수행한 실제 변경사항을 시간 순서대로 기록한다.
- 대상 스택:
  - `infra/network`
  - `infra/security`
  - `infra/compute`
  - `infra/cdn`
  - `infra/iam` (신규)
- 운영 자동화:
  - `ansible/*`
  - GitHub OIDC Role(`GitHubActions-Deploy-Role`) 권한/신뢰정책

## 2) 현재 기준 리소스 상태
- VPC: `vpc-0748ee7da6c386861`
- Public Subnet: `subnet-0a4f71ff33428690d`
- Private Subnet A: `subnet-047324ec024aefc25`
- Private Subnet B: `subnet-0d2d0fd602e522a37`
- Bastion+NAT:
  - Instance: `i-00fbfcdfb106037d2`
  - Public DNS: `ec2-54-180-151-216.ap-northeast-2.compute.amazonaws.com`
  - Public IP: `54.180.151.216`
- Nginx:
  - Instance: `i-08ff154c333e80490`
  - Public DNS: `ec2-43-201-51-112.ap-northeast-2.compute.amazonaws.com`
  - Public IP: `43.201.51.112`
- FE:
  - Instance: `i-0d5c31c492e4bc9eb`
  - Private IP: `10.0.11.228`
- CloudFront:
  - ID: `E3T1SF1FP2TR`
  - Domain: `d1xf7hpa4b4zbr.cloudfront.net`
- S3 Static Bucket: `doktori-fe-static-246477585940-dev`

## 3) Terraform 변경 상세
### 3-1) `infra/compute` Ubuntu 전환
- Amazon Linux 기반 AMI에서 Ubuntu 24.04 AMI로 변경.
- Bastion NAT user_data를 Ubuntu 패키지 체계(apt)로 변경.
- NAT 인터페이스를 고정 `eth0`가 아닌 동적 인터페이스 탐지 방식으로 변경.
- Nginx user_data를 Ubuntu 경로(`/etc/nginx/sites-available/default`) 기준으로 변경.

### 3-2) `infra/cdn` 오리진 업데이트
- SSR 오리진을 새 Nginx DNS로 교체:
  - `ec2-54-180-247-20...` -> `ec2-43-201-51-112...`
- 동작:
  - `/_next/static/*` -> S3
  - `/*` -> Nginx(Custom origin, `http-only`)

### 3-3) `infra/iam` 신규 스택 생성
- 신규 리소스:
  - IAM Role: `doktori-fe-ec2-role`
  - Instance Profile: `doktori-fe-ec2-profile`
  - Policy attach:
    - `AmazonSSMManagedInstanceCore`
    - `AmazonEC2ContainerRegistryReadOnly`
- 목적:
  - FE 인스턴스에서 SSM 관리 + ECR pull 권한 확보.

### 3-4) FE 인스턴스 Profile 연결
- `infra/compute`에서 FE 전용 profile 변수 추가 후 FE에만 연결.
- 적용 결과:
  - FE 재생성 없이 `in-place`로 `doktori-fe-ec2-profile` 연결 완료.

## 4) Ansible 변경 상세
### 4-1) 인벤토리/접속
- Ubuntu 전환 후 계정 `ec2-user` -> `ubuntu`로 전환.
- Bastion 프록시 경유 설정 최신 DNS로 변경.

### 4-2) Playbook 변경
- `bootstrap.yml`: `dnf` -> `apt`
- `fe.yml`:
  - `dnf` -> `apt`
  - Docker: `docker.io` 패키지
  - AWS CLI: apt 패키지 대신 공식 zip 설치 방식
  - docker group 대상 유저를 `ubuntu`로 변경
- `nginx.yml`:
  - `dnf` -> `apt`
  - 업스트림 호스트를 인벤토리 FE host 변수로 참조
  - Ubuntu 기본 사이트 경로 사용

### 4-3) SSM Agent
- FE에서 `amazon-ssm-agent` 서비스 상태 확인 및 활성화.
- 최종 상태:
  - FE 인스턴스 `Online` 확인 (Systems Manager Managed Instance).

## 5) GitHub OIDC / IAM 변경 상세
### 5-1) Trust Policy 수정 (수동 반영)
- Role: `GitHubActions-Deploy-Role`
- OIDC provider: `token.actions.githubusercontent.com`
- `sub` 허용 목록에 아래 추가:
  - `repo:JI1047/5-team-service-fe:ref:refs/heads/main`
  - `repo:JI1047/5-team-service-fe:ref:refs/heads/develop`
  - `repo:JI1047/5-team-service-fe:ref:refs/heads/feature/cicd`

### 5-2) Deploy 권한 정책 추가 (`infra/iam`)
- Role: `GitHubActions-Deploy-Role`
- Inline policy: `doktori-gha-deploy-permissions`
- 포함 권한:
  - ECR push/pull 관련 최소 권한
  - S3 static bucket sync 권한
  - `ssm:SendCommand`, `ssm:ListCommandInvocations`, `ssm:GetCommandInvocation`
  - `ec2:DescribeInstances`

### 5-3) SSM 문서 ARN 수정
- 기존 권한 리소스가 계정 포함 ARN이라 매칭 실패.
- 수정 후:
  - `arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript`
- 결과:
  - OIDC AssumeRole 이후 `SendCommand` 단계 권한 오류 해소.

## 6) CI/CD 연동 관련 확인 사항
### 6-1) 비밀값(Secrets) 조회 완료
- `S3_STATIC_BUCKET_DEV`: `doktori-fe-static-246477585940-dev`
- `S3_STATIC_BUCKET_PROD`: `doktori-fe-static-246477585940-dev` (테스트 동일값)
- `CLOUDFRONT_DISTRIBUTION_ID_DEV`: `E3T1SF1FP2TR`
- `CLOUDFRONT_DISTRIBUTION_ID_PROD`: `E3T1SF1FP2TR` (테스트 동일값)
- `AWS_DEPLOY_ROLE_ARN`: `arn:aws:iam::246477585940:role/GitHubActions-Deploy-Role`
- ECR URI:
  - Registry: `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com`
  - Repository: `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com/fe-test`

### 6-2) 현재 남은 배포 이슈
- SSM `SendCommand --targets`를 사용할 경우 대상 태그 일치 필요.
- 현재 FE 태그:
  - `Role=fe`
  - `Name=doktori-fe-fe`
  - `Stack=compute`
  - `Project=doktori-fe`
- 즉, 아래 태그는 아직 없음:
  - `Environment=dev`
  - `Service=frontend`
- 워크플로우가 `--targets Key=tag:Environment,Values=dev Key=tag:Service,Values=frontend`를 사용하면 `None`/타임아웃 가능.

### 6-3) FE 런타임/정적 서빙 상태
- FE private 인스턴스 Docker 컨테이너 기동 확인:
  - Container: `frontend`
  - Image: `246477585940.dkr.ecr.ap-northeast-2.amazonaws.com/fe-test:sha-c20a1f3`
  - Port: `3000:3000`
- Nginx 프록시 설정 복구 완료:
  - `/etc/nginx/sites-available/default`에 `proxy_pass http://10.0.11.228:3000;` 적용
- CloudFront 루트 응답은 Next.js SSR로 정상 전환 확인.
- 단, 브라우저에서 정적 JS/CSS 다수 로드 실패 관측:
  - 원인 추정: SSR 이미지 버전과 S3 정적 파일 버전 불일치(해시 mismatch)
  - 조치 필요: 동일 커밋 기준으로 SSR+정적 동시 배포 + CloudFront invalidation

## 7) 드리프트/주의사항
- `GitHubActions-Deploy-Role` Trust Policy는 AWS CLI로 수동 업데이트됨.
- Terraform 코드(`infra/iam`)에 trust policy 리소스를 아직 선언하지 않았으면 추후 드리프트 가능.
- 테스트 종료 시 destroy 순서 준수 필요:
  1. `infra/cdn`
  2. `infra/compute`
  3. `infra/iam`
  4. `infra/security`
  5. `infra/network`

## 8) 내일 실행 체크리스트 (2026-02-16)
### A. 팀 합의(먼저 확정)
- 네이밍 규칙 확정:
  - VPC/Subnet/SG/EC2/Role/CloudFront/S3 버킷 이름 규칙
- 배포 운영 방식 확정:
  - SSM target 방식(태그 기준 vs 인스턴스 ID 직접 지정)
  - dev/prod 버킷/배포판 분리 여부

### B. 배포 파이프라인 정리
- `5-team-service-fe` 워크플로우를 한 가지 방식으로 통일:
  - 권장: SSM 기반 배포로 통일
- 필수 Secret 값 재검증:
  - `AWS_DEPLOY_ROLE_ARN`
  - `S3_STATIC_BUCKET_DEV/PROD`
  - `CLOUDFRONT_DISTRIBUTION_ID_DEV/PROD`

### C. 정적/동적 버전 정합성 복구
1. 동일 커밋 기준 FE 이미지 재빌드/재배포
2. 동일 커밋 기준 `.next/static`, `public` S3 재업로드
3. CloudFront invalidation:
   - `/_next/static/*`
   - `/public/*`
   - `/`
4. 브라우저 하드 리프레시 후 JS/CSS 200 확인

### D. SSM 타깃 안정화
- `SendCommand --targets`를 계속 쓸 경우 FE 태그 추가:
  - `Environment=dev`
  - `Service=frontend`
- 대안: 인스턴스 ID 직접 지정 방식으로 workflow 변경

### E. 테스트 환경 정리(선택)
- 오늘 완전 철거 시 순서:
  1. `infra/cdn destroy`
  2. `infra/compute destroy`
  3. `infra/iam destroy`
  4. `infra/security destroy`
  5. `infra/network destroy`

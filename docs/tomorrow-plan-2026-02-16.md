# Tomorrow Plan (2026-02-16)

## 1) 목표
- 이름/역할 체계를 팀과 합의한 뒤 재구성.
- FE 배포를 정적(S3) + 동적(EC2/컨테이너)로 안정화.
- OIDC + SSM 배포 경로를 재현 가능하게 고정.

## 2) 우선순위
1. 네이밍/구조 합의 (BE/Cloud 담당 포함)
2. CI/CD 워크플로우 최종 방식 확정 (SSM vs SSH 혼용 제거)
3. 정적/동적 동시 배포 버전 정합성 복구
4. 회귀 테스트 후 필요 시 리소스 재생성

## 3) 상세 태스크
### A. 설계 합의
- 버킷/배포판 분리 여부(dev/prod 동일 사용 여부) 재결정
- Role/Policy naming 통일
- 태그 전략 통일:
  - `Environment`
  - `Service`
  - `Project`

### B. CI/CD 정리
- GitHub Actions에서 OIDC Role 사용 유지
- SSM 명령 타깃 방식 결정:
  - 태그 기반이면 FE에 `Environment=dev`, `Service=frontend` 강제
  - 인스턴스 ID 기반이면 태그 의존 제거

### C. 배포 정합성
1. 동일 commit SHA로 FE 이미지 빌드/배포
2. 동일 SHA 기준 `.next/static`, `public` S3 업로드
3. CloudFront invalidation 실행
4. 브라우저 네트워크 탭에서 JS/CSS 오류 0 확인

### D. 검증
- `https://d1xf7hpa4b4zbr.cloudfront.net/` 접속 시 렌더 정상
- FE 컨테이너 상태 `Up`
- SSM 상태 `Online`
- 워크플로우 재실행 시 `AssumeRole/SendCommand` 에러 없음

## 4) 선택 작업 (오늘 밤 철거 시)
- Terraform destroy 순서:
  1. `infra/cdn`
  2. `infra/compute`
  3. `infra/iam`
  4. `infra/security`
  5. `infra/network`

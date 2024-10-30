## 가이드라인

* PR은 `develop`브랜치에서 시작해야 합니다.
* 새로운 패키지를 추가하지 마세요. 기존 패키지를 제거할 수 있는 수정은 환영입니다.
* Git hooks를 설정해주세요. (`dart foramt .` 실행)
  ```bash
  # 프로젝트 디렉토리 이동
  cd /path/your/coconut_wallet
  
  # Git hook 로컬 경로 설정
  git config --local core.hooksPath .git/hooks

  # pre-commit.sample 제거
  rm -rf .git/hooks/pre-commit.sample

  # pre-commit 생성 및 script 추가
  vi .git/hooks/pre-commit

  # 실행 권한 부여
  chmod +x .git/hooks/pre-commit
  ```

  `pre-commit script`
  ```bash
  #!/bin/bash
  dart format . --set-exit-if-changed
  if [[ $? -ne 0 ]]; then
    echo "코드 포맷팅에 문제가 있습니다. 다시 커밋해 주세요."
    exit 1
  fi
  exit 0
  ```

## Commits

모든 커밋과 브랜치명은 다음의 접두사 중 하나를 사용해야 합니다. `feat`, `fix`, `style`, `refactor`, `chore`, `docs`. 예를 들어 `feat(new): 새로운 기능`형식의 커밋과 `feat/new`와 같은 브랜치명 형식입니다.

- `feat`: 기능 추가
- `fix`: 버그 수정
- `style`: 코드 포맷팅, 로직 변경이 없는 경우
- `refactor`: 코드 리팩토링
- `chore`: 빌드 관련 수정, 패키지 매니저 수정
- `docs`: 문서 수정

## Releases

- **release 브랜치**는 `1.0`처럼 major, minor 버전별로 관리합니다. 예를 들어 `1.0` 버전은 `1.0.0`부터 패치된 횟수가 2번이라면 **release-1.0 브랜치에** `1.0.0~1.0.2` 버전까지 기록되어 있어야 합니다.
- **모든 release 브랜치는** **삭제하지 않습니다.**
- minor 버전 값이 업데이트 되어 `1.0.2`버전에서 `1.1.0`버전이 된다면 새로운 브랜치 **release-1.1**을 만들고 이 브랜치에 **develop** 브랜치를 머지해야 합니다. 
- **만약 release 과정에서 변경 사항이 생기면 우선, 별다른 문제가 없는 경우 develop에서 브랜치를 따서 작업 후 release 브랜치에 머지하는 것으로 합니다.** 
- release-x.y 배포가 완료되면 **github TAG**를 달아줍니다. 예를 들어 1.0.0버전이라면 최종적으로 ios가 배포된 커밋에 `1.0.0-ios`, 최종적으로 aos가 배포된 커밋에 `1.0.0-aos` TAG를 추가해줍니다.

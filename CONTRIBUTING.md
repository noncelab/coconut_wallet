# Contributing | 기여하기

## Guidelines | 가이드라인

- PRs must be based on the `develop` branch.</br>
  PR은 `develop` 브랜치에서 시작해야 합니다.

- Do not add new packages. Modifications that remove existing packages are welcome.</br>
  새로운 패키지를 추가하지 마세요. 기존 패키지를 제거할 수 있는 수정은 환영입니다.

- Please set up Git hooks (`dart format .`):</br>
  Git hooks를 설정해주세요:

  ```bash
  cd /path/your/coconut_wallet

  git config --local core.hooksPath .git/hooks

  rm -rf .git/hooks/pre-commit.sample

  vi .git/hooks/pre-commit

  chmod +x .git/hooks/pre-commit
  ```

  `pre-commit` script:

  ```bash
  #!/bin/bash
  dart format . --set-exit-if-changed --line-length=120
  if [[ $? -ne 0 ]]; then
    echo "Code formatting issues found. Please reformat and commit again."
    exit 1
  fi
  exit 0
  ```

---

## CCOS Contributions | CCOS 기여

- If your change is a new feature or extension — not a fix or improvement to something that already exists — start with the [CCOS docs](./docs/ccos/README.md) instead of the general flow below.</br>
  기존 기능의 수정이나 개선이 아니라 새로운 기능·확장을 제안하는 경우, 아래 일반 절차 대신 [CCOS 문서](./docs/ccos/README.md)부터 확인해 주세요.

- Every CCOS proposal is classified as 🟢 Green / 🟡 Yellow / 🔴 Red before implementation. See [feature_boundary.md](./docs/ccos/getting_started/feature_boundary.md).</br>
  모든 CCOS 제안은 구현 전에 🟢 Green / 🟡 Yellow / 🔴 Red로 분류됩니다. [feature_boundary.md](./docs/ccos/getting_started/feature_boundary.md)를 참고해 주세요.

- CCOS PRs use a dedicated template: [ccos_contribution.md](./.github/PULL_REQUEST_TEMPLATE/ccos_contribution.md).</br>
  CCOS PR은 별도 템플릿([ccos_contribution.md](./.github/PULL_REQUEST_TEMPLATE/ccos_contribution.md))을 사용합니다.

---

## Commits | 커밋

All commit messages and branch names must use one of the following prefixes.
</br>모든 커밋과 브랜치명은 다음의 접두사 중 하나를 사용해야 합니다.

| Prefix | Description | 설명 |
|--------|-------------|------|
| `feat` | New feature | 기능 추가 |
| `fix` | Bug fix | 버그 수정 |
| `style` | Code formatting (no logic changes) | 코드 포맷팅, 로직 변경 없음 |
| `refactor` | Code refactoring | 코드 리팩터링 |
| `chore` | Build config, package manager | 빌드 관련 수정, 패키지 매니저 |
| `docs` | Documentation | 문서 수정 |
| `test` | Tests | 테스트 코드 작성 |

**Commit format / 커밋 형식:** `feat(new): new feature`

**Branch format / 브랜치 형식:** `feat/new`

---

## Releases | 릴리즈

- **Release branches** are managed per major.minor version (e.g. `release-1.0`). For example, if version `1.0` has been patched twice, the `release-1.0` branch should contain versions `1.0.0` through `1.0.2`.
</br> release 브랜치는 `1.0`처럼 major.minor 버전별로 관리합니다. 예를 들어 `1.0` 버전이 2번 패치되었다면, release-1.0 브랜치에 `1.0.0`~`1.0.2` 버전이 기록되어야 합니다.

- **Never delete release branches.**</br>
  모든 release 브랜치는 삭제하지 않습니다.

- When the minor version is bumped (e.g. `1.0.2` → `1.1.0`), create a new `release-1.1` branch and merge `develop` into it.</br> 
minor 버전이 올라가면 (예: `1.0.2` → `1.1.0`), 새로운 `release-1.1` 브랜치를 만들고 `develop` 브랜치를 머지합니다.

- If changes are needed during the release process, branch off from `develop`, make the changes, and merge into the release branch.</br>
release 과정에서 변경 사항이 생기면, `develop`에서 브랜치를 따서 작업 후 release 브랜치에 머지합니다.

- After a `release-x.y` deployment is complete, add GitHub tags. For example, for version `1.0.0`: tag the final iOS deploy commit as `1.0.0-ios` and the final Android deploy commit as `1.0.0-aos`.</br>
release-x.y 배포가 완료되면 GitHub TAG를 추가합니다. 예를 들어 `1.0.0` 버전이라면 iOS 배포 커밋에 `1.0.0-ios`, Android 배포 커밋에 `1.0.0-aos` 태그를 추가합니다.

---

## Localization (i18n) | 문구 수정

When modifying text strings, edit the base locale file `assets/i18n/ko.i18n.yaml`, and update the other locale files under `assets/i18n/` (`en`, `ja`, `es`, `de`). Then run the following command to regenerate the localization files:</br>
문구 변경 시 기준 언어 파일인 `assets/i18n/ko.i18n.yaml`을 수정하고, `assets/i18n/` 아래의 다른 언어 파일(`en`, `ja`, `es`, `de`)도 함께 수정해 주세요. 이후 아래 명령어를 실행하면 `lib/localization/`의 `strings_ko.g.dart`, `strings.g.dart` 파일이 업데이트됩니다.

```bash
flutter pub run slang
```
You can also run this via `make slang` (defined in the `Makefile`).</br>
`make slang`으로도 동일하게 실행할 수 있어요 (Makefile에 정의되어 있습니다).


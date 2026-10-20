# Reference

Quy ước đầy đủ (bản dành cho agent):
[`references/sdd-conventions.md`](../../references/sdd-conventions.md).

## Lệnh

| Lệnh | Khi nào | Kết quả |
|---|---|---|
| `/engineer:init-docs` | Một lần cho mỗi repo | `docs/` + `CLAUDE.md` |
| `/engineer:requirement [ý tưởng]` | Bắt đầu một version | `build/vX` + `requirement.md` |
| `/engineer:plan` | Sau requirement | `plan.md` + feature tests |
| `/engineer:architect` | Sau plan | `docs/` cập nhật + `architecture.md` |
| `/engineer:build [--approved]` | Sau architect; tiếp tục; `uat-fix: …` | code, test, code review, PR #1 + PR #2. `--approved`: tự duyệt mọi đề xuất phát sinh khi build (vẫn dừng ở các trường hợp an toàn) |
| `/engineer:code-review [--approved]` | Sau khi mọi goal Done, trước ship (`build` tự gọi) | review toàn bộ version (`/code-review` hoặc agent review), áp dụng sửa/tối ưu, chạy lại mọi test, `code-review.md` |
| `/engineer:ship [--skip-test ["<lý do>"]]` | Tiếp tục ship bị ngắt; hoặc mở PR mà không chạy test (chỉ khi bạn tự gõ) | 2 PR; với `--skip-test` cả 2 PR có cảnh báo **Tests skipped** |
| `/engineer:release stag` | Sau khi merge PR #2 | tag `vX-rc.N` trên `main` |
| `/engineer:release prod` | Sau khi UAT pass | merge PR #1, tag `vX` trên `release`, GitHub Release |
| `/engineer:release prod --uat-waived "<lý do>"` | Không có STAG/UAT (ngoại lệ) | như trên, lý do ghi vào tag và release notes |
| `/engineer:status` | Bất cứ lúc nào | bảng trạng thái + bước tiếp theo |
| `/engineer:guide` | Onboarding, hỏi đáp | hướng dẫn |
| `/engineer:feedback` | Plugin có vấn đề | GitHub issue |
| `/engineer:run-tests`, `/engineer:sync-docs` | Chạy riêng khi cần | test report / docs đồng bộ |

## Nhánh và tag

| Tên | Ý nghĩa |
|---|---|
| `main` | STAG |
| `release` | PROD |
| `build/vX.Y.Z.T` | Nhánh tích hợp, tạo từ `release`, giữ chỗ version |
| `port/vX.Y.Z.T` | Cherry-pick của build lên `main` |
| `vX.Y.Z.T-rc.N` | Tag STAG trên `main` |
| `vX.Y.Z.T` | Tag PROD trên `release` |

PR luôn merge bằng **merge commit** (không squash).

## Version `X.Y.Z.T`

| Số | Tăng khi | Loại bump | Commit type |
|---|---|---|---|
| X | Không tương thích bản cũ | `major` | `feat!` / `BREAKING CHANGE:` |
| Y | Feature mới | `feature` | `feat` |
| Z | Cải tiến chức năng sẵn có | `improvement` | `improve`, `perf`, `refactor` |
| T | Sửa lỗi | `fix` | `fix` |

Tăng một số → các số sau về 0. Chưa có tag → gốc `0.0.0.0`.

## Trạng thái

`approved → planned → architected → building → in-review → staging (rc.N) → released`
(+ `abandoned`). Lưu trong frontmatter `requirement.md`; `staging` và
`released` suy ra từ tag.

## File

```
docs/plans/vX.Y.Z.T/requirement.md | plan.md | architecture.md | code-review.md | test-report.md
docs/test-cases/feature-tests/<domain>/FT-vX.Y.Z.T-NN-<slug>.md
docs/test-cases/unit-tests/vX.Y.Z.T.md
docs/04-conventions/testing.md      # commands: setup / lint / unit / feature
CHANGELOG.md                        # Keep a Changelog
```

Repo có bộ docs riêng: đường dẫn thật khai báo trong `.claude/engineer.yml`
(xem "Docs layout" trong `sdd-conventions.md`); các đường dẫn trên là mặc định.
Cũng trong file đó, `test_report_ignore` liệt kê thêm các đường dẫn mà thay đổi
không làm test report hết hiệu lực (docs, `CHANGELOG.md`, `.claude/` luôn được bỏ
qua).

## ID

`REQ-NN`, `G-NN`, `D-NN` (quyết định thiết kế, trong `architecture.md`) — trong một version · `FT-vX.Y.Z.T-NN` (duy nhất toàn repo) ·
`INV-NNN` · `ADR-NNNN`. Test tự động phải có FT-ID trong tên test.

## Commit (Conventional Commits — bắt buộc)

`<type>(<scope>)!: <mô tả>` — type: `feat fix perf refactor improve docs test
build ci chore style revert`. Commit của goal có trailer
`Refs: vX.Y.Z.T/G-NN` — trailer thật của git: nằm ở đoạn cuối, chung một khối
với `Co-Authored-By:`, không có dòng trống xen giữa. Repo dùng commitlint phải cho
phép type `improve` (`scripts/commitlint-check.sh`).

## Feedback

Hàng đợi: `~/.claude/engineer-feedback/queue/` · Issue:
the plugin repository (`repository` in `plugin.json`, or `$ENGINEER_FEEDBACK_REPO`).

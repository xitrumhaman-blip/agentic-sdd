---
title: Agentic SDD — quy trình phát triển sản phẩm với plugin engineer
status: accepted
date: 2026-10-08
owner: PhongPx
---

# Agentic SDD

Bản thiết kế đã chốt cho bộ skill/agent của plugin `engineer`. Đây là căn cứ khi
triển khai và khi sửa plugin về sau. Quy ước chi tiết cho agent nằm ở
[`plugins/engineer/references/sdd-conventions.md`](../../plugins/engineer/references/sdd-conventions.md);
hướng dẫn cho người dùng nằm ở [`plugins/engineer/docs/guide/`](../../plugins/engineer/docs/guide/README.md).

## 1. Mục tiêu

Một quy trình **Spec-Driven Development (SDD)** dùng chung cho mọi repo sản phẩm
(khác stack nhau), trong đó con người chốt ở các cổng duyệt, còn agent làm phần
soạn thảo, triển khai, test và mở PR.

## 2. Môi trường và nhánh

| Nhánh | Môi trường | Tag kích hoạt |
|---|---|---|
| `main` | STAG | `vX.Y.Z.T-rc.N` |
| `release` | PROD | `vX.Y.Z.T` |
| `build/vX.Y.Z.T` | Nhánh tích hợp của một version, tạo từ `release` | — |
| `port/vX.Y.Z.T` | Bản cherry-pick của `build/vX` lên `main` | — |

Thứ tự: **STAG trước, PROD sau.**

```
release ──► build/vX  (tạo lúc chốt requirement; mọi docs + code commit ở đây)
               ├── PR #1: build/vX → release      (mở cùng lúc, CHƯA merge)
main ────► port/vX ◄── cherry-pick -x từ build/vX, chạy lại toàn bộ test
               └── PR #2: port/vX → main ─merge─► tag vX-rc.N ─► STAG ─► UAT
                    UAT fail: sửa trên build/vX → pick lại → rc.N+1
                    UAT pass: merge PR #1 → tag vX ─► PROD
```

CI/CD (deploy theo tag) làm ở giai đoạn sau; giai đoạn này skill chỉ đánh tag.

## 3. Version

- 4 số `X.Y.Z.T`: X = thay đổi không tương thích, Y = feature mới, Z = cải tiến
  chức năng sẵn có, T = sửa lỗi. Tăng một số thì các số thấp hơn về 0. Requirement
  gồm nhiều loại thì lấy bậc cao nhất.
- Gốc tính: tag PROD mới nhất trên `release` (chưa có thì `0.0.0.0`).
- **Giữ chỗ**: nhánh `origin/build/vX` tồn tại nghĩa là version đã có người dùng.
  Trùng thì tăng tiếp cùng bậc.
- Version chỉ nằm trong git tag (không ghi vào `package.json`, `Cargo.toml`… vì
  các manifest đó chỉ nhận 3 số).
- Version gán lúc **chốt** requirement, vì loại bump phụ thuộc nội dung.

## 4. Chuẩn được áp dụng

| Phần | Chuẩn |
|---|---|
| Quy trình | Spec-Driven Development |
| Commit / PR title | Conventional Commits (bắt buộc). `feat`→Y, `fix`→T, `perf`/`refactor`/`improve`→Z, `!`/`BREAKING CHANGE`→X. `improve` là type bổ sung của quy trình này (spec cho phép type tự định nghĩa) |
| Changelog | Keep a Changelog (entry được viết lúc `ship`, ngày phát hành xem GitHub Release) |
| ADR | Michael Nygard |
| Sơ đồ kiến trúc | C4 model (Context, Container) vẽ bằng Mermaid |
| Feature test | BDD / Gherkin (Given/When/Then) |
| WBS | Hướng deliverable (PMI) + Definition of Done |
| Nhánh | Environment branches (main=STAG, release=PROD), promote bằng cherry-pick |
| Tài liệu onboarding | Diátaxis (Tutorial, How-to, Reference, Explanation) |

## 5. Artifact trong repo sản phẩm

```
docs/
├── plans/vX.Y.Z.T/
│   ├── requirement.md     # /engineer:requirement
│   ├── plan.md            # /engineer:plan   (WBS + State)
│   ├── architecture.md    # /engineer:architect
│   └── test-report.md     # engineer:run-tests
├── test-cases/
│   ├── feature-tests/<domain>/FT-vX.Y.Z.T-NN-<slug>.md   # nguồn gốc, Gherkin
│   └── unit-tests/vX.Y.Z.T.md                            # bảng ánh xạ goal → unit test
└── … (00-context … 06-agent-guide do init-docs tạo; bỏ 05-specs)
```

- Unit test code nằm cạnh source theo convention của stack; `docs/` chỉ chứa ánh xạ.
- Feature test: file `.md` là nguồn gốc; bản automated viết bằng framework của
  stack, tên test chứa FT-ID; bản manual do agent chạy và ghi bằng chứng vào
  `test-report.md`.
- Lệnh chạy test nằm trong frontmatter `commands:` của `docs/04-conventions/testing.md`.
- `05-specs/` bị bỏ: thay đổi theo version nằm ở `plans/`, hành vi hiện hành
  ("living spec") là bộ feature test.

## 6. Vòng đời trạng thái

`approved → planned → architected → building → in-review → staging → released`
(+ `abandoned`). Lưu ở frontmatter `requirement.md` cho tới `in-review` (đặt khi
cả 2 PR đã mở); `staging` và `released` suy ra từ tag (`-rc.N`, `vX`).

## 7. Danh sách skill / agent

**Skill gọi trực tiếp** (`/engineer:<tên>`)

| Skill | Việc |
|---|---|
| `init-docs` | Tạo `docs/` + `CLAUDE.md` (đã bổ sung `plans/`, `test-cases/`, lệnh test, C4, Conventional Commits) |
| `requirement` | Thảo luận → chốt → tính version → tạo `build/vX` → `requirement.md` |
| `plan` | `plan.md` + feature test |
| `architect` | Thiết kế đầy đủ của version: cập nhật `docs/` (ADR, invariant, C4) + `architecture.md` với mọi quyết định build cần (`D-NN`), duyệt một lần |
| `build` | Điều phối WBS qua `goal-builder`/`goal-verifier` → `run-tests` → `sync-docs` → `code-review` → `ship`; `--approved` tự duyệt các đề xuất phát sinh |
| `code-review` | Review toàn bộ version bằng `/code-review` (khi harness cho phép) hoặc agent review, áp dụng sửa/tối ưu qua `goal-builder`, chạy lại mọi test, `code-review.md` |
| `release` | `stag`: tag `-rc.N` trên main. `prod`: merge PR #1, tag `vX` trên release, GitHub Release |
| `status` | Bảng trạng thái các version + bước tiếp theo + số feedback chưa gửi |
| `guide` | Onboarding, hỏi đáp, tutorial trên repo sandbox do người dùng tạo |
| `feedback` | Gom feedback từ conversation + hàng đợi → GitHub issue trên repo plugin |

**Skill hỗ trợ** (skill khác gọi): `next-version`, `start-build`, `run-tests`,
`ship`, `sync-docs`. `ship`, `run-tests`, `sync-docs` cũng gọi trực tiếp được
(ví dụ `/engineer:ship` để tiếp tục khi bị ngắt); `release` chỉ người gọi được.

**Subagent**: `codebase-analyzer` (chỉ đọc), `goal-builder`, `goal-verifier` (chỉ đọc).

**Chỉ có trong repo plugin**: skill `/triage`, issue templates, script tạo label.

## 8. Feedback

- Mỗi skill kết thúc bằng bước **retro** chạy ngầm: nếu có trục trặc (người dùng
  sửa output, script lỗi, phải làm lại…) thì ghi một mục vào
  `~/.claude/engineer-feedback/queue/` (ngoài repo, không chứa source code/secret).
- `/engineer:feedback` đọc conversation hiện tại + hàng đợi → gom, loại trùng, tìm
  issue đã có → cho người dùng xem bản nháp → `gh issue create` lên
  the plugin repository (`repository` in `plugin.json`, or `$ENGINEER_FEEDBACK_REPO`).
- Repo plugin dùng `/triage` để gom và xếp ưu tiên issue. Repo plugin không tự
  chạy chu trình SDD (version plugin phải là SemVer 3 số trong `plugin.json`):
  sửa trên `main`, tăng version + CHANGELOG, maintainer đưa `main` lên `release`.
- Quét transcript session cũ: để giai đoạn sau.

## 9. Cổng duyệt của con người

1. Chốt requirement. 2. Duyệt plan. 3. Duyệt ADR/kiến trúc. 4. Đồng ý mở PR.
5. Review + merge PR #2 (STAG). 6. Xác nhận UAT pass → release PROD.
Skill luôn hỏi trước khi push, mở PR, tạo tag, gửi issue. Ngoại lệ có kiểm
soát: `/engineer:build --approved` duyệt trước mọi đề xuất phát sinh trong lúc
build (kể cả mở PR), ghi lại từng lần tự duyệt và gom vào PR #1; đổi scope,
invariant, ADR cũ, test fail/skip, force-push, merge và tag vẫn luôn hỏi.

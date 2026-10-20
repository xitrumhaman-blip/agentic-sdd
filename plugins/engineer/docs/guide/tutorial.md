# Tutorial — Chu trình đầu tiên

Bạn sẽ đưa một feature nhỏ từ ý tưởng lên STAG (tag `-rc.1`), rồi lên PROD, trên
một **repo sandbox của riêng bạn**. Mất khoảng 45–60 phút. Không cần biết trước
quy trình.

## 0. Chuẩn bị (10 phút)

1. Cài plugin (một lần):
   ```
   /plugin marketplace add OWNER/agentic-sdd
   /plugin install engineer@agentic-sdd
   ```
2. Kiểm tra `gh auth status` đã đăng nhập GitHub.
3. **Tạo repo sandbox** trên GitHub (trong tài khoản của bạn hoặc org, private
   cũng được), ví dụ `sdd-sandbox-<tên-bạn>`. Gợi ý nội dung: một app rất nhỏ
   bằng stack bạn quen (ví dụ API Node/Express hoặc FastAPI có 1 endpoint và 1
   unit test).
4. Tạo 2 nhánh môi trường:
   ```bash
   git push origin main            # STAG
   git push origin main:release    # PROD
   ```
5. Clone repo về máy, mở Claude Code trong thư mục đó, gõ
   `/engineer:guide tutorial` và đưa URL repo sandbox khi được hỏi.

## 1. Khởi tạo tài liệu kiến trúc

```
/engineer:init-docs
```

Agent đọc repo, hỏi tên và mô tả một dòng, rồi tạo `docs/` và `CLAUDE.md`.
Xem nhanh `docs/README.md` và `docs/04-conventions/testing.md` (lệnh chạy test
nằm trong frontmatter `commands:`). Commit lên `main` rồi đưa sang `release`
(`git push origin main:release`), vì nhánh build được tạo từ `release`. Ở
sandbox, `main` và `release` đang giống nhau nên push thẳng được; ở repo thật
xem [how-to](how-to.md#áp-dụng-cho-một-repo-mới-hoặc-repo-đang-có-code).

## 2. Discovery — chốt requirement

```
/engineer:requirement Thêm endpoint /health trả về version và uptime
```

Trả lời các câu hỏi của agent. Để ý cách agent:
- tách **Goals** và **Non-goals**,
- viết acceptance criteria dạng `WHEN … THE SYSTEM SHALL …`,
- chọn loại bump (`feature`) và tính version (`v0.1.0.0` vì repo chưa có tag).

Khi bạn chốt, agent tạo nhánh `build/v0.1.0.0` từ `release`, commit
`docs/plans/v0.1.0.0/requirement.md` và push.

## 3. Plan

```
/engineer:plan
```

Đọc `plan.md`: WBS là **mục tiêu** (outcome) kèm Definition of Done, không phải
task code. Xem feature test trong `docs/test-cases/feature-tests/`.

## 4. Architect

```
/engineer:architect
```

Với feature nhỏ, agent có thể kết luận "không đổi kiến trúc" — vẫn có
`architecture.md` hướng dẫn builder. Để ý bảng **Design decisions** (`D-NN`):
mọi quyết định build cần đều được chốt ở đây, bạn duyệt một lần cùng các ADR.

## 5. Build

```
/engineer:build
```

Theo dõi từng goal: `goal-builder` viết code + test, `goal-verifier` kiểm tra
độc lập, State chuyển `To Do → WIP → Done`. Cuối cùng agent chạy toàn bộ test,
đồng bộ docs, gọi `/engineer:code-review` (review toàn bộ version bằng `/code-review`
hoặc agent review, áp dụng các sửa đổi được chấp nhận, chạy lại mọi test), rồi hỏi bạn
trước khi mở 2 PR:

- PR #1 `build/v0.1.0.0 → release` (chưa merge)
- PR #2 `port/v0.1.0.0 → main`

> Muốn build chạy một mạch không dừng hỏi: `/engineer:build --approved`. Mọi
> đề xuất phát sinh (quyết định, mục cần duyệt, sửa đổi từ review, mở PR)
> được tự duyệt và ghi lại trong mục **Auto-approved during build** của PR #1
> để bạn xem trước khi merge. Đổi scope, sửa invariant, test fail/skip vẫn
> dừng lại hỏi.

## 6. Lên STAG

Merge PR #2 trên GitHub bằng **Create a merge commit**, rồi:

```
/engineer:release stag
```

Agent tạo tag `v0.1.0.0-rc.1` trên `main` và đưa bạn checklist UAT.

> Thử vòng sửa lỗi: giả sử UAT phát hiện `/health` thiếu trường `uptime`.
> Chạy `/engineer:build uat-fix: /health thiếu uptime`, merge PR #2 lần nữa,
> `/engineer:release stag` → `v0.1.0.0-rc.2`.

## 7. Lên PROD

```
/engineer:release prod
```

Agent kiểm tra STAG đã chạy đủ commit, hỏi bạn xác nhận UAT pass, merge PR #1,
tạo tag `v0.1.0.0` trên `release` và GitHub Release.

## 8. Xem lại

```
/engineer:status
```

Bạn vừa đi hết một chu trình. Nếu có chỗ nào khó hiểu hoặc agent làm sai, gõ
`/engineer:feedback` — agent tự gom từ cuộc trò chuyện, bạn chỉ cần duyệt.

# How-to

Công thức cho các tình huống thường gặp. Mỗi mục giả định bạn đã hiểu chu trình
cơ bản ([tutorial](tutorial.md)).

## Áp dụng cho một repo mới hoặc repo đang có code
1. Đảm bảo có nhánh `main` (STAG) và `release` (PROD) trên `origin`.
2. `/engineer:init-docs` — với repo đã có code, agent dùng `codebase-analyzer`
   để mô tả kiến trúc thật; mục chưa chắc được đánh dấu `TODO: confirm`.
3. Rà `docs/02-constraints/invariants.md` (2–5 quy tắc thật) và
   `docs/04-conventions/testing.md` (`commands:` đúng chưa).
4. Nếu repo dùng commitlint, agent kiểm tra type `improve` có được chấp nhận
   không và đề nghị thêm vào `type-enum` (`references/commitlint.md`).
5. Commit lên `main` (`docs: initialize architecture knowledge base`). Nếu đang
   có `build/vX` chạy, agent cherry-pick commit đó sang `build/vX` để nó lên
   `release` qua PR #1 của version. Nếu không có version nào đang chạy, đưa
   **đúng commit đó** sang `release` (PROD):
   - `main` không có gì khác chưa lên PROD (`git rev-list origin/release..origin/main`
     chỉ ra commit docs) → `git push origin main:release`;
   - ngược lại → tạo nhánh `chore/init-docs` từ `origin/release`, `cherry-pick -x`
     commit docs, mở PR vào `release`. Agent sẽ hỏi trước khi push/mở PR.

## Repo đã có sẵn bộ docs riêng
Không cần chuyển file sang cấu trúc của `init-docs`. Chạy `/engineer:init-docs`
và chọn **adopt**: agent đối chiếu file sẵn có (invariants, ADR, conventions…)
với các vai trò SDD, ghi bản đồ vào `.claude/engineer.yml`, và chỉ thêm phần
còn thiếu (`commands:` cho test, thư mục `plans/`, `test-cases/`). Invariant
giữ cách đánh số cũ (khai báo trong `invariant_id`, ví dụ `"#{n}"`). Kiểm tra:
`bash <plugin>/scripts/docs-layout.sh`.

## UAT trên STAG phát hiện lỗi
1. `/engineer:build uat-fix: <bước tái hiện, mong đợi, thực tế>`
2. Agent sửa trên `build/vX`, chạy lại test, cập nhật PR #1 và port commit mới
   sang `port/vX` (PR #2 mới hoặc cập nhật).
3. Merge PR #2 (merge commit) → `/engineer:release stag` → `vX-rc.N+1`.

## PO đổi scope khi đang build
1. `/engineer:requirement revise <thay đổi>` — tạm dừng build, ghi **Revision N**
   vào `requirement.md` (REQ cũ giữ số, REQ bỏ đi bị gạch, REQ mới lấy số kế
   tiếp), PO duyệt lại.
2. `/engineer:plan` — goal bị bỏ thành `Dropped`, goal đã Done mà bị ảnh hưởng
   quay về `To Do`, goal mới thêm vào cuối; feature test được sửa/xoá/deprecate.
3. `/engineer:architect` — cập nhật hoặc supersede ADR theo phần thay đổi.
4. `/engineer:build` — tiếp tục với các goal chưa Done.

## Sửa lỗi gấp trên PROD (hotfix)
Hotfix đi lại **cả chu trình**, chỉ là nhỏ hơn: `/engineer:requirement` (bump
`fix` → tăng T), plan ngắn, architect thường kết luận "không đổi kiến trúc",
build, STAG, PROD.

## Resolve conflict khi port sang main
`engineer:ship` tự xử lý: khi `port.sh` báo conflict, agent mở worktree
`<repo>-port-vX`, giữ cả thay đổi đang có trên `main` (có thể của version khác
đang ở STAG) lẫn thay đổi của version này, rồi chạy lại test trên nhánh port.
Khi không chắc ý đồ, agent hỏi bạn. `CHANGELOG.md`: giữ mọi entry, version mới
ở trên.

## Hai version chạy song song
- Số version được giữ chỗ bằng nhánh `origin/build/vX`, nên không bị trùng.
- PROD phải nhận version theo thứ tự tăng dần. Nếu version lớn hơn lên PROD
  trước, `/engineer:release prod` của version nhỏ sẽ dừng và đề nghị **đánh số
  lại** (đổi tên nhánh và thư mục plan, chạy lại ship + rc).

## Release lên PROD không qua UAT (chưa có môi trường STAG)
```
/engineer:release prod --uat-waived "chưa có môi trường STAG, PO đã duyệt trên bản demo"
```
Agent vẫn chạy các kiểm tra (rc tag, commit chưa lên `main`) và liệt kê những
gì bị bỏ qua, hỏi xác nhận riêng cho việc bỏ UAT (ghi rõ người quyết định), rồi
ghi lý do vào tag (`UAT waived: …`, `Waived by: …`) và đầu release notes. Thứ
tự version vẫn bắt buộc. Xem lại các lần bỏ UAT: `git tag -n99 | grep "UAT waived"`.

Nếu PR #1 đã bị merge trước khi UAT xong, `/engineer:release prod` sẽ báo rõ
(kèm thời điểm merge và thời điểm rc) thay vì bỏ qua.

## Mở PR mà không chạy test
```
/engineer:ship --skip-test "suite e2e cần môi trường chỉ có trên CI"
```
Chỉ bạn mới bật được (agent không tự chọn, `--approved` không bao gồm). Ship
không chạy test và không bắt buộc test report/code review còn mới, nhưng vẫn
kiểm tra goal Done, Conventional Commits, commitlint. Cả 2 PR mở đầu bằng cảnh
báo **Tests skipped** (lý do, người yêu cầu, trạng thái test report gần nhất),
và `/engineer:release` nhắc lại khi xin xác nhận — UAT trên STAG phải bù phần
này.

## Huỷ một version
1. Đặt `status: abandoned` trong `requirement.md`, commit, push (để lưu vết),
   hoặc bỏ qua bước này nếu không cần lưu.
2. Đóng PR #1/#2 nếu đã mở.
3. Xoá nhánh `build/vX` (và `port/vX`) trên remote → số version được giải phóng.

## Tiếp tục một version ở session khác
`/engineer:status` → chạy lệnh ở cột "Next step". `build` tự tiếp tục từ goal
chưa `Done` nhờ cột State trong `plan.md`.

## Thêm lệnh test hoặc framework e2e
Đây là quyết định kiến trúc: để `/engineer:architect` viết ADR và cập nhật
`commands:` trong `docs/04-conventions/testing.md`.

## Báo lỗi hoặc góp ý cho plugin
`/engineer:feedback`. Agent đọc cuộc trò chuyện + hàng đợi feedback (ghi tự
động khi skill gặp trục trặc), soạn issue, bạn duyệt rồi mới gửi lên
the plugin repository (`repository` in `plugin.json`, or `$ENGINEER_FEEDBACK_REPO`).

## Nâng cấp từ plugin 0.2 khi repo có bộ docs riêng
Từ 0.3, đường dẫn docs được đọc qua `.claude/engineer.yml`. Repo đã chạy SDD
với 0.2 mà để invariants/ADR/conventions ở chỗ khác sẽ được báo
`hint	adopt-needed` (không phải "chưa có docs"): chạy `/engineer:init-docs`, chọn
**adopt** một lần để map lại. Không cần di chuyển file nào.

## Cập nhật plugin
```
/plugin marketplace update agentic-sdd
```

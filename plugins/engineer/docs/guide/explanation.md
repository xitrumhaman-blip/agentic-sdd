# Explanation — vì sao quy trình như vậy

## Spec trước, code sau
Agent viết code rất nhanh nhưng dễ "đoán" ý định. Agentic SDD buộc mọi version
đi qua requirement → plan → kiến trúc trước khi build, để agent build theo một
bản đặc tả đã được người duyệt, không theo phỏng đoán. Cách làm này gọi là
**Spec-Driven Development** (giống GitHub Spec Kit, AWS Kiro).

## Người chốt, agent làm
Mỗi phase kết thúc ở một **cổng duyệt**. Agent không tự push, mở PR, tạo tag hay
gửi issue khi chưa hỏi. Lý do: những hành động đó ra ngoài máy bạn và khó thu hồi.

## Requirement, plan, architect là skill — không phải subagent
Subagent chạy trong context riêng và không hỏi đáp qua lại được. Ba phase đầu
cần thảo luận với bạn, nên chạy trong cuộc trò chuyện chính. Việc nặng và cần
context sạch (quét code, build từng goal, kiểm tra DoD) mới giao cho subagent.

## WBS là mục tiêu, không phải task
Plan nói **cái gì phải đúng** khi xong (outcome + Definition of Done), không nói
code thế nào. Nhờ vậy plan ổn định, builder tự do chọn cách làm theo kiến trúc,
và verifier có tiêu chí rõ ràng để chấm.

## Architect chốt toàn bộ thiết kế, build chỉ làm theo
Mỗi lần build phải dừng lại hỏi một quyết định là một lần ngắt quãng và một
vòng hỏi đáp với người. Vì vậy `/engineer:architect` giao ra **thiết kế đầy
đủ**: mọi quyết định build cần (nguồn dữ liệu, hành vi khi các cơ chế gặp
nhau, giới hạn chống lạm dụng, tham số chỉ chốt được bằng đo đạc…) được ghi
thành `D-NN` và duyệt một lần ở cổng architect. Mỗi giá trị, cơ chế đã chốt
cũng được đối chiếu với quy ước bắt buộc của repo (tài liệu quy ước, lint,
type-check, CI): cần ngoại lệ thì ngoại lệ đó cũng là một `D-NN`, và tài liệu
quy ước ghi rõ ngoại lệ — builder không được tự thêm lệnh tắt lint. Architect
cũng xác nhận lại với PO các giá trị mặc định người dùng nhìn thấy mà client
mới kế thừa từ ADR cũ (ngôn ngữ, trang đầu, định dạng…), và với mỗi quy tắc
"ai được ghi X" thì quyết định cơ chế thực thi ở tầng quyền (DB, IAM…) cùng
cách chống tự khoá quyền. Build chỉ quyết thêm khi gặp
điều thật sự không lường trước; mỗi lần như vậy được ghi lại để cải thiện
hướng dẫn cho architect.

## Review toàn bộ version trước khi ship
`goal-verifier` kiểm từng goal; `/engineer:code-review` nhìn cả version một
lượt — bằng `/code-review` khi môi trường cho phép, nếu không thì bằng agent
review chạy trên đúng phần thay đổi của version — để bắt lỗi giữa các goal, lỗi bảo mật, code trùng
lặp hoặc chưa tối ưu. Sửa đổi được áp dụng qua `goal-builder` (giữ quy ước,
trailer `Refs:`), không được đi ngược `D-NN`/ADR/invariant, và toàn bộ test
được chạy lại trước khi ship.

## `--approved` là duyệt trước, không phải bỏ duyệt
`/engineer:build --approved` cho build chạy liền mạch, nhưng mỗi lần tự duyệt
đều được ghi lại đúng chỗ một lần duyệt của người sẽ nằm, và gom vào PR #1 để
người review trước khi merge. Những việc có thể gây hại lâu dài (đổi scope,
invariant, ADR cũ, test fail/skip, force-push, merge, tag) vẫn luôn hỏi.

## Builder không tự chấm bài
`goal-verifier` là agent khác, chỉ đọc, kiểm từng mục DoD bằng bằng chứng. Một
goal chỉ `Done` khi verifier PASS.

## Nhánh build tạo từ `release`, không từ `main`
`main` (STAG) có thể đang chứa version khác chưa được duyệt lên PROD. Build từ
`release` đảm bảo PR vào PROD chỉ mang đúng version này. Sang STAG thì
cherry-pick (`port/vX`).

## STAG trước, PROD sau
PR #1 (PROD) mở cùng lúc nhưng chỉ merge sau khi UAT trên STAG pass. Lỗi UAT
được sửa trên `build/vX` để PR #1 luôn là bản đã được test trên STAG.

## Merge commit, không squash
Cherry-pick dùng `-x`, để lại dòng `(cherry picked from commit …)` trên `main`.
Script dựa vào dòng này để biết commit nào đã lên STAG trong các vòng sửa UAT.
Squash xoá dấu vết đó.

## Giữ chỗ version bằng nhánh
Hai người cùng làm hai version không được tính ra cùng một số. Nhánh
`origin/build/vX` tồn tại = số đã có người dùng. Không cần server hay file khoá.

## Version 4 số chỉ nằm trong tag
`package.json`, `Cargo.toml`… chỉ nhận 3 số. Vì vậy version sống trong tag,
tên nhánh và đường dẫn `docs/plans/`, không ghi vào manifest.

## Feature test là "living spec"
Thư mục `docs/plans/` ghi lại **thay đổi** theo từng version. Hành vi **hiện
hành** của sản phẩm là bộ feature test (Gherkin) — luôn được chạy, luôn đúng.
Vì vậy bỏ `05-specs/`.

## Feedback tự ghi nhận
Phần lớn góp ý nằm sẵn trong cuộc trò chuyện. Mỗi skill tự ghi lại trục trặc
vào hàng đợi trên máy bạn (bước "retro"); `/engineer:feedback` soạn issue từ đó,
bạn chỉ cần duyệt.

## Chuẩn tham chiếu
Spec-Driven Development · Conventional Commits · Keep a Changelog · ADR (Michael
Nygard) · C4 model · BDD/Gherkin · EARS · WBS + Definition of Done · Environment
branches · Diátaxis.

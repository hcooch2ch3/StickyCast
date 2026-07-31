import Foundation

/// atomic-save(temp+rename)에도 살아남는 파일 감시 (S2 스파이크 정식화, 스펙 §4).
/// 파일 fd DispatchSource + rename/delete 시 debounce 후 경로 재확인·재-arm.
/// security-scoped URL을 fd 수명 내내 보유(N1) — 비샌드박스 near-no-op이나 구조를 갖춘다.
/// 스레드 계약: 콜백은 메인 큐. 호출부(컨트롤러)는 메인. 순수 Foundation이라 Core에 두어 유닛 테스트.
public final class FileWatcher {
    private struct Watch { let source: DispatchSourceFileSystemObject; let scopedURL: URL; let accessing: Bool }
    private var watches: [UUID: Watch] = [:]
    // 진행 중인 debounce 재-arm을 취소 가능하게 보유(Finding #1): teardown/unwatch가
    // 예약된 재-arm을 반드시 무효화해야 detach/삭제 후 좀비 감시 부활·fd 누수·헛 다이얼로그를 막는다.
    private var rearmWork: [UUID: DispatchWorkItem] = [:]

    public init() {}

    /// url에 접근 시작(security-scope) 후 fd 감시 arm. 기존 watch는 교체.
    public func watch(noteID: UUID, url: URL, onChange: @escaping () -> Void) {
        unwatch(noteID: noteID)
        arm(noteID: noteID, url: url, onChange: onChange)
    }

    private func arm(noteID: UUID, url: URL, onChange: @escaping () -> Void) {
        let accessing = url.startAccessingSecurityScopedResource()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { if accessing { url.stopAccessingSecurityScopedResource() }; return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self] in self?.handle(noteID: noteID, url: url, flags: src.data, onChange: onChange) }
        src.setCancelHandler { close(fd) }
        watches[noteID] = Watch(source: src, scopedURL: url, accessing: accessing)
        src.resume()
    }

    private func handle(noteID: UUID, url: URL, flags: DispatchSource.FileSystemEvent, onChange: @escaping () -> Void) {
        if flags.contains(.write) || flags.contains(.extend) { onChange() }
        if flags.contains(.delete) || flags.contains(.rename) {
            // atomic swap/rename: 현재 fd는 낡음 → 원자적 stop-old, debounce 후 재-arm(§4).
            // teardown이 이전 예약을 취소하므로 rapid rename도 최신 예약 1개만 남는다.
            teardown(noteID: noteID)
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.rearmWork[noteID] = nil
                if FileManager.default.fileExists(atPath: url.path) {
                    self.arm(noteID: noteID, url: url, onChange: onChange)
                    onChange()   // 재-arm = 파일 변경으로 판정부에 통지 (통일된 "재평가" ping)
                } else {
                    onChange()   // 진짜 삭제 → 판정부(§7)가 재확인 후 삭제 처리
                }
            }
            rearmWork[noteID] = work
            // ⚠️ 불변식: 이 재-arm 지연(0.15s)은 AppDelegate self-write 억제 창(0.3s)보다 반드시 작아야
            // atomic-save의 self-write 재발화가 억제 안에 들어와 헛 배너를 막는다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

    public func unwatch(noteID: UUID) { teardown(noteID: noteID) }
    public func unwatchAll() { Array(watches.keys).forEach { teardown(noteID: $0) } }   // 스냅샷 — 반복 중 변형 방지

    private func teardown(noteID: UUID) {
        rearmWork[noteID]?.cancel()   // 진행 중 재-arm 예약 무효화(Finding #1) — watch 없어도 실행돼야 함
        rearmWork[noteID] = nil
        guard let w = watches.removeValue(forKey: noteID) else { return }
        w.source.cancel()
        if w.accessing { w.scopedURL.stopAccessingSecurityScopedResource() }
    }
}

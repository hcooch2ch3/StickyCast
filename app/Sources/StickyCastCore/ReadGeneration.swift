import Foundation

/// 노트별 monotonic 세대 카운터 — 비동기 파일 읽기의 out-of-order 완료를 latest-wins로 폐기(Finding #2).
///
/// `.write`/`.extend`는 디바운스 없이 즉시 발화하고 `readLinkedFile`은 순서 보장 없는 global 큐로
/// 던지므로, 빠른 연속 저장 시 완료가 역순으로 main에 도착해 스티커가 파일보다 뒤처져 고착될 수 있다.
/// 읽기 시작 시 `begin`으로 토큰을 발급하고, 완료 시 `isCurrent`로 최신 세대인지 검사해 아니면 버린다.
///
/// 스레드 계약: **메인 큐 전용**(handleFileEvent·완료 콜백 모두 main) — 락 없음.
public final class ReadGeneration {
    private var current: [UUID: Int] = [:]

    public init() {}

    /// 새 읽기 시작 — 이 노트의 세대를 1 올리고 토큰을 반환한다.
    public func begin(_ id: UUID) -> Int {
        let g = (current[id] ?? 0) + 1
        current[id] = g
        return g
    }

    /// 완료 결과를 반영해도 되는지 — 발급받은 토큰이 아직 최신 세대일 때만 true.
    public func isCurrent(_ id: UUID, _ token: Int) -> Bool {
        current[id] == token
    }
}

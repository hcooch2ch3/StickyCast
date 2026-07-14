import Foundation
import CoreGraphics

public enum StickyStoreError: Error, Equatable {
    case capReached          // 스티커 장수(maxStickies) 초과
    case contentTooLarge     // 콘텐츠 바이트(maxContentBytes) 초과
}

public struct StickyNote: Codable, Identifiable, Equatable {
    public let id: UUID
    public var content: String
    public var frame: CGRect
    public var opacity: Double
    public let createdAt: Date
}

/// 스티커 상태의 단일 진실 소스. AppKit 창 코드와 무관 — 단위 테스트 대상.
/// 저장 정책(§5.2): 이산 이벤트(add/remove)는 즉시, 연속 제스처는 commit* 호출 시에만.
///
/// 스레드 계약: **메인 스레드 전용**. 유일 호출부는 AppKit `application(_:open:)`과 UI 콜백으로
/// 전부 메인 스레드에서 실행된다. `notes`는 동기화하지 않으므로 오프-메인 접근 시 데이터 레이스 (iter-008 리뷰).
public final class StickyStore {
    private static let schemaVersion = 1
    public static let maxStickies = 30
    // 콘텐츠 바이트 한도 — 확장 limits.ts의 MAX_CONTENT_BYTES와 동일 값의 단일 소스(앱 측).
    // 쓰기(add)와 읽기(restore) 양쪽에서 강제해 저장·렌더 부담을 막는다 (재리뷰: restore 경로 갭).
    public static let maxContentBytes = 1 * 1024 * 1024
    private static let storageKey = "stickyStore.v1"
    private static let cardSize = CGSize(width: 320, height: 240)
    private static let margin: CGFloat = 16
    private static let cascadeOffset: CGFloat = 24

    private struct Container: Codable {
        var schemaVersion: Int
        var notes: [FailableNote]
    }
    /// 항목 단위 실패 격리: 깨진 항목은 nil로 디코드
    private struct FailableNote: Codable {
        let note: StickyNote?
        init(_ note: StickyNote) { self.note = note }
        init(from decoder: Decoder) throws {
            note = try? StickyNote(from: decoder)
        }
        func encode(to encoder: Encoder) throws {
            try note?.encode(to: encoder)
        }
    }

    private let defaults: UserDefaults
    private let screenFrame: CGRect
    public private(set) var notes: [StickyNote] = []

    public init(defaults: UserDefaults, screenFrame: CGRect) {
        self.defaults = defaults
        self.screenFrame = screenFrame
    }

    public func add(content: String) -> Result<StickyNote, StickyStoreError> {
        guard content.utf8.count <= Self.maxContentBytes else { return .failure(.contentTooLarge) }
        guard notes.count < Self.maxStickies else { return .failure(.capReached) }
        let note = StickyNote(
            id: UUID(), content: content,
            frame: nextFrame(index: notes.count),
            opacity: 1.0, createdAt: Date()
        )
        notes.append(note)
        save()
        return .success(note)
    }

    public func remove(id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    public func commitFrame(id: UUID, frame: CGRect) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].frame = frame
        save()
    }

    public func commitOpacity(id: UUID, opacity: Double) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].opacity = opacity
        save()
    }

    public func restore() {
        guard let data = defaults.data(forKey: Self.storageKey) else { return }
        let container: Container
        do {
            container = try JSONDecoder().decode(Container.self, from: data)
        } catch {
            NSLog("StickyStore: restore 실패 (컨테이너 디코드) — %@", "\(error)")  // §7 조용한 실패 금지
            return
        }
        // 마이그레이션 경계: 미지원 버전은 로드하지 않는다 (v1으로 덮어써 다운그레이드/손실 방지)
        guard container.schemaVersion == Self.schemaVersion else {
            NSLog("StickyStore: 미지원 schemaVersion %d (지원 %d) — 복원 건너뜀", container.schemaVersion, Self.schemaVersion)
            return
        }
        // 복원 정규화: over-cap 저장(손상/다운그레이드/구버전 큰 노트 잔여)이 flood/렌더 프리즈를
        // 일으키지 않도록, 콘텐츠 바이트 초과 노트를 버리고 장수도 maxStickies로 제한한다.
        // (재리뷰 MAJOR: restore가 예전 24MB 캡 시절 >1MB 노트를 무가드로 렌더하던 갭 차단.)
        notes = Array(
            container.notes.compactMap(\.note)
                .filter { $0.content.utf8.count <= Self.maxContentBytes }
                .prefix(Self.maxStickies)
        )
    }

    private func save() {
        let container = Container(schemaVersion: Self.schemaVersion, notes: notes.map(FailableNote.init))
        do {
            let data = try JSONEncoder().encode(container)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            NSLog("StickyStore: save 실패 (인코드) — %@", "\(error)")  // §7 조용한 실패 금지
        }
    }

    /// 우상단 기준 캐스케이드. 화면을 벗어나면 시작 위치로 순환.
    private func nextFrame(index: Int) -> CGRect {
        let startX = screenFrame.maxX - Self.cardSize.width - Self.margin
        let startY = screenFrame.maxY - Self.cardSize.height - Self.margin
        let maxSteps = max(1, Int(min(
            (startX - screenFrame.minX) / Self.cascadeOffset,
            (startY - screenFrame.minY) / Self.cascadeOffset
        )))
        let step = CGFloat(index % maxSteps)
        return CGRect(
            x: startX - step * Self.cascadeOffset,
            y: startY - step * Self.cascadeOffset,
            width: Self.cardSize.width, height: Self.cardSize.height
        )
    }
}

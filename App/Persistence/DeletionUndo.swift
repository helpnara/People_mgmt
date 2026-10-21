import Foundation
import SwiftData
import SwiftUI

/// **삭제 실행취소** (FR-031 · D-53) — 사람 · 기록을 지운 직후 5초 동안 `되돌리기`.
///
/// 지우기(저장까지)를 저장소 문맥의 `UndoManager` 한 묶음으로 담았다가, 누르면 그 묶음을 되돌리고 다시 저장한다.
/// 사람을 지울 때 함께 지운 단독 기록 · 아는 사이 연결, 공동 기록에서 빠진 자리, 비워진 소개자 칸이 한 번에 돌아온다.
/// - 묶음을 닫은 뒤에는 담기를 끈다 — 5초 사이의 다른 고침이 되돌리기에 섞이지 않게.
/// - 5초가 지나거나 다른 삭제가 오면 묶음을 버린다. 되돌리기는 늘 가장 최근 삭제 하나다.
/// - 확인 창(모든 삭제에 확인 · CLAUDE.md)은 그대로 둔다. 실행취소는 확인 뒤의 실수를 위한 것이다.
@MainActor
@Observable
final class DeletionUndo {
    static let shared = DeletionUndo()
    static let window: Duration = .seconds(5)

    struct Pending: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    /// 지금 띄울 알림. 없으면 nil.
    private(set) var pending: Pending?
    @ObservationIgnored private var manager: UndoManager?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var timer: Task<Void, Never>?

    /// `work` 는 지우고 저장까지 한다(`PersonStore.delete` · `RecordStore.delete`). 실패하면 던지고 알림을 띄우지 않는다.
    func run(_ message: String, in context: ModelContext, _ work: () throws -> Void) throws {
        finish()
        let manager = UndoManager()
        manager.groupsByEvent = false
        context.undoManager = manager
        manager.beginUndoGrouping()
        do {
            try work()
        } catch {
            manager.endUndoGrouping()
            context.undoManager = nil
            throw error
        }
        manager.endUndoGrouping()
        manager.disableUndoRegistration()
        guard manager.canUndo else {
            context.undoManager = nil
            return
        }
        self.manager = manager
        self.context = context
        pending = Pending(message: message)
        timer = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// 되돌리고 저장한다. 되돌렸으면 true.
    @discardableResult
    func undo() -> Bool {
        defer { finish() }
        guard let manager, let context, manager.canUndo else { return false }
        manager.undo()
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            return false
        }
    }

    /// 묶음을 버리고 알림을 내린다.
    func finish() {
        timer?.cancel()
        timer = nil
        context?.undoManager = nil
        context = nil
        manager = nil
        pending = nil
    }
}

/// 화면 아래의 `되돌리기` 알림 — 뿌리 화면이 하나만 둔다.
struct DeletionUndoBanner: View {
    let undo: DeletionUndo

    var body: some View {
        if let pending = undo.pending {
            HStack(spacing: 12) {
                Text(pending.message)
                    .font(.scaled(15))
                    .foregroundStyle(Color.ink)
                    .readableLineLimit(2)
                Spacer(minLength: 8)
                Button {
                    withAnimation { _ = undo.undo() }
                } label: {
                    Text("되돌리기")
                        .font(.scaled(15, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .tapTarget()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .background(Color.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.rule, lineWidth: 1))
            .shadow(color: Color.ink.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(pending.id)
        }
    }
}

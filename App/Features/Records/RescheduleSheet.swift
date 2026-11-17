import SwiftUI

/// **다른 날로 다시 잡기** (13판 · 이슈 117 · D-81) — 안 만난 약속은 남기고, 같은 내용의 새 약속을 고른 날에 만든다.
/// 날짜는 오늘부터 고른다. 시각은 원래 약속에 있었으면 그 시각에서 시작한다.
struct RescheduleSheet: View {
    let record: Record
    /// 새 약속을 만들었을 때 — 부른 화면이 안내를 띄운다.
    var onDone: (Record) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var minute: Int?
    @State private var started = false
    @State private var errorMessage: String?

    private var hasTime: Binding<Bool> {
        Binding(get: { minute != nil }, set: { on in
            if on {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
                minute = record.occurredMinute ?? (parts.hour ?? 12) * 60 + ((parts.minute ?? 0) / 30) * 30
            } else {
                minute = nil
            }
        })
    }

    private var timeOfDay: Binding<Date> {
        Binding(get: {
            let value = minute ?? 12 * 60
            return Calendar.current.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: Date()) ?? Date()
        }, set: { picked in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: picked)
            minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("날짜", selection: $date, in: Calendar.current.startOfDay(for: Date())...,
                               displayedComponents: .date)
                        .accessibilityIdentifier("rescheduleDate")
                    Toggle("시각 넣기", isOn: hasTime)
                    if minute != nil {
                        DatePicker("시각", selection: timeOfDay, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("지금 기록은 안 만난 약속으로 남고, 같은 사람 · 제목 · 장소로 새 약속을 만듭니다. 사진은 옮기지 않습니다.")
                }
            }
            .navigationTitle("다른 날로 다시 잡기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("다시 잡기") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("rescheduleSave")
                }
            }
            .alert("저장하지 못했습니다", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("닫기", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            minute = record.occurredMinute
        }
    }

    private func save() {
        do {
            let copy = try RecordStore(context: context).reschedule(record, to: date, minute: minute)
            onDone(copy)
            dismiss()
        } catch {
            errorMessage = "\(error.localizedDescription) 기기 저장 공간이 부족하지 않은지 확인한 뒤 다시 시도해 주세요."
        }
    }
}

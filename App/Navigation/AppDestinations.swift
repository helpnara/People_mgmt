import SwiftData
import SwiftUI

/// **값으로 여는 목적지 모음** (이슈 16 · 32). 앱은 화면을 값(`Person` · `…Route`)으로 쌓는다.
/// 아이폰은 목록의 스택 하나, 아이패드는 칸마다 스택이 있다 — 어느 스택이든 같은 목적지를 이 한 곳에서 붙인다.
extension View {
    func appDestinations() -> some View {
        self
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: person)
            }
            .navigationDestination(for: Record.self) { record in
                RecordDetailView(record: record)
            }
            .navigationDestination(for: NetworkRoute.self) { route in
                NetworkView(initialTab: route.tab)
            }
            .navigationDestination(for: PersonID.self) { ref in
                PersonByIDView(id: ref.id)
            }
            .navigationDestination(for: PeopleListRoute.self) { route in
                PeopleRouteView(route: route)
            }
            .navigationDestination(for: EvidenceRoute.self) { route in
                EvidenceRouteView(route: route)
            }
            .navigationDestination(for: RecordFillRoute.self) { route in
                RecordFillRouteView(route: route)
            }
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView()
            }
            .navigationDestination(for: AcquaintanceSuggestionRoute.self) { route in
                AcquaintanceSuggestionsView(route: route)
            }
    }
}

/// **아이패드 왼쪽 바의 칸** (이슈 32 · 2026-10-20 사용자 선택). 사람 · 내 인맥 넷 · 설정.
enum AppSection: Hashable {
    case people
    case network(NetworkView.Tab)
    case settings
}

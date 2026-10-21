import Contacts
import ContactsUI
import Core
import Foundation
import UIKit
import VisionKit

/// 맨 위에 떠 있는 화면 위로 시스템 화면(문서 카메라 · 연락처 선택기)을 띄운다.
///
/// SwiftUI 시트 안에서 이 두 화면을 `UIViewControllerRepresentable` 로 띄우면 연락처 선택기가 곧장 닫히는
/// 경우가 알려져 있다. 그래서 UIKit 쪽에서 맨 위 화면을 찾아 그 위에 띄운다 — 시트 위에도 뜬다.
@MainActor
enum TopPresenter {
    static func topController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    static func present(_ controller: UIViewController) {
        topController()?.present(controller, animated: true)
    }
}

/// 명함 촬영 (FR-050) — 문서 카메라가 명함 테두리를 **자동으로 찾아** 반듯하게 편다. 첫 장만 쓴다.
/// 시뮬레이터에는 카메라가 없어 `isAvailable` 이 거짓이다 — 그때 단추를 숨긴다.
@MainActor
final class DocumentScanner: NSObject, VNDocumentCameraViewControllerDelegate {
    static let shared = DocumentScanner()

    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }

    private var completion: ((Data?) -> Void)?
    private weak var presented: UIViewController?

    func start(_ completion: @escaping (Data?) -> Void) {
        guard Self.isAvailable else {
            completion(nil)
            return
        }
        self.completion = completion
        let controller = VNDocumentCameraViewController()
        controller.delegate = self
        presented = controller
        TopPresenter.present(controller)
    }

    private func finish(_ data: Data?) {
        presented?.dismiss(animated: true)
        presented = nil
        let completion = self.completion
        self.completion = nil
        completion?(data)
    }

    // 대리자 메서드는 `nonisolated` 로 두고 **값(Data)만 뽑아** 주 스레드로 넘긴다 —
    // 프로토콜이 주 스레드 고정이든 아니든 같은 코드로 서게 (Swift 6 · CLAUDE.md 의 `@preconcurrency` 금지).
    nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        let data = scan.pageCount > 0 ? scan.imageOfPage(at: 0).jpegData(compressionQuality: 0.9) : nil
        Task { @MainActor [weak self] in self?.finish(data) }
    }

    nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        Task { @MainActor [weak self] in self?.finish(nil) }
    }

    nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.finish(nil) }
    }
}

/// 사람 사진 촬영 (FR-012) — 시스템 카메라. 찍은 사진은 `PersonPhoto` 가 줄인다.
/// 시뮬레이터에는 카메라가 없어 `isAvailable` 이 거짓이다 — 그때 단추를 숨긴다.
@MainActor
final class PhotoCamera: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = PhotoCamera()

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private var completion: ((Data?) -> Void)?
    private weak var presented: UIViewController?

    func start(_ completion: @escaping (Data?) -> Void) {
        guard Self.isAvailable else {
            completion(nil)
            return
        }
        self.completion = completion
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraDevice = .front
        controller.delegate = self
        presented = controller
        TopPresenter.present(controller)
    }

    private func finish(_ data: Data?) {
        presented?.dismiss(animated: true)
        presented = nil
        let completion = self.completion
        self.completion = nil
        completion?(data)
    }

    // 문서 카메라와 같이 `nonisolated` 로 두고 값(Data)만 뽑아 주 스레드로 넘긴다.
    nonisolated func imagePickerController(_ picker: UIImagePickerController,
                                           didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let data = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9)
        Task { @MainActor [weak self] in self?.finish(data) }
    }

    nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Task { @MainActor [weak self] in self?.finish(nil) }
    }
}

/// 연락처에서 고른 한 사람 — 앱에 필요한 글자만 (FR-015).
struct PickedContact: Sendable {
    var given = ""
    var family = ""
    var organization = ""
    var department = ""
    var jobTitle = ""
    /// 번호와 그 이름표(휴대전화 · 직장 · 직장 팩스 …) — 칸을 나누는 근거다 (이슈 11).
    var phones: [ContactSorter.LabeledValue] = []
    var emails: [String] = []
}

/// 연락처 가져오기 (FR-015). 시스템 선택기라 **연락처 권한을 묻지 않는다** — 사용자가 고른 한 사람만 앱에 온다.
/// 전체를 읽거나 동기화하지 않는다.
@MainActor
final class ContactPicker: NSObject, CNContactPickerDelegate {
    static let shared = ContactPicker()

    private var completion: ((PickedContact?) -> Void)?

    func start(_ completion: @escaping (PickedContact?) -> Void) {
        self.completion = completion
        let controller = CNContactPickerViewController()
        controller.delegate = self
        TopPresenter.present(controller)
    }

    private func finish(_ picked: PickedContact?) {
        let completion = self.completion
        self.completion = nil
        completion?(picked)
    }

    nonisolated func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        // 가져오지 않은 칸을 읽으면 앱이 죽는다 — 칸마다 있는지 먼저 본다.
        func available(_ key: String) -> Bool { contact.isKeyAvailable(key) }
        var picked = PickedContact()
        if available(CNContactGivenNameKey) { picked.given = contact.givenName }
        if available(CNContactFamilyNameKey) { picked.family = contact.familyName }
        if available(CNContactOrganizationNameKey) { picked.organization = contact.organizationName }
        if available(CNContactDepartmentNameKey) { picked.department = contact.departmentName }
        if available(CNContactJobTitleKey) { picked.jobTitle = contact.jobTitle }
        if available(CNContactPhoneNumbersKey) {
            picked.phones = contact.phoneNumbers.map {
                ContactSorter.LabeledValue(label: $0.label ?? "", value: $0.value.stringValue)
            }
        }
        if available(CNContactEmailAddressesKey) { picked.emails = contact.emailAddresses.map { String($0.value) } }
        Task { @MainActor [weak self] in self?.finish(picked) }
    }

    nonisolated func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        Task { @MainActor [weak self] in self?.finish(nil) }
    }
}

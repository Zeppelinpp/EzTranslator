import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            complete()
            return
        }

        let plainTextType = "public.plain-text"
        let textType = "public.text"

        let targetType: String
        if itemProvider.hasItemConformingToTypeIdentifier(plainTextType) {
            targetType = plainTextType
        } else if itemProvider.hasItemConformingToTypeIdentifier(textType) {
            targetType = textType
        } else {
            complete()
            return
        }

        itemProvider.loadItem(forTypeIdentifier: targetType, options: nil) { [weak self] (item, error) in
            guard let text = item as? String else {
                self?.complete()
                return
            }

            self?.enqueueTranslation(text: text)

            if let url = URL(string: "floattranslator://translate") {
                self?.extensionContext?.open(url, completionHandler: { _ in
                    self?.complete()
                })
            } else {
                self?.complete()
            }
        }
    }

    private func enqueueTranslation(text: String) {
        let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
        let queueKey = "translationQueue"

        var queue: [[String: String]] = []
        if let data = defaults?.data(forKey: queueKey),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            queue = existing
        }

        let request: [String: String] = [
            "id": UUID().uuidString,
            "text": text
        ]
        queue.append(request)

        if let data = try? JSONSerialization.data(withJSONObject: queue) {
            defaults?.set(data, forKey: queueKey)
            defaults?.synchronize()
        }
    }

    private func complete() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

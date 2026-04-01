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

            let defaults = UserDefaults(suiteName: AppSettings.appGroupID)
            defaults?.set(text, forKey: "pendingTranslationText")
            defaults?.synchronize()

            if let url = URL(string: "floattranslator://translate") {
                self?.extensionContext?.open(url, completionHandler: { _ in
                    self?.complete()
                })
            } else {
                self?.complete()
            }
        }
    }

    private func complete() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}

import UIKit

class ShareViewController: UIViewController {

    private let sourceTextView = UITextView()
    private let translatedTextView = UITextView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadSharedText()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Source Text Label
        let sourceLabel = UILabel()
        sourceLabel.text = "Source"
        sourceLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        sourceLabel.textColor = UIColor.secondaryLabel
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        // Source Text View
        sourceTextView.isEditable = false
        sourceTextView.font = UIFont.preferredFont(forTextStyle: .body)
        sourceTextView.backgroundColor = UIColor.secondarySystemBackground
        sourceTextView.layer.cornerRadius = 8
        sourceTextView.translatesAutoresizingMaskIntoConstraints = false

        // Translated Text Label
        let translatedLabel = UILabel()
        translatedLabel.text = "Translation"
        translatedLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        translatedLabel.textColor = UIColor.secondaryLabel
        translatedLabel.translatesAutoresizingMaskIntoConstraints = false

        // Translated Text View
        translatedTextView.isEditable = false
        translatedTextView.font = UIFont.preferredFont(forTextStyle: .body)
        translatedTextView.backgroundColor = UIColor.secondarySystemBackground
        translatedTextView.layer.cornerRadius = 8
        translatedTextView.translatesAutoresizingMaskIntoConstraints = false

        // Activity Indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        // Status Label
        statusLabel.text = "Translating..."
        statusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Done Button
        doneButton.setTitle("Done", for: .normal)
        doneButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        doneButton.backgroundColor = UIColor.systemBlue
        doneButton.setTitleColor(UIColor.white, for: .normal)
        doneButton.layer.cornerRadius = 8
        doneButton.addTarget(self, action: #selector(complete), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        view.addSubview(sourceLabel)
        view.addSubview(sourceTextView)
        view.addSubview(translatedLabel)
        view.addSubview(translatedTextView)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        view.addSubview(doneButton)

        // Layout
        NSLayoutConstraint.activate([
            // Source Label
            sourceLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            sourceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sourceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Source Text View
            sourceTextView.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 4),
            sourceTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sourceTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sourceTextView.heightAnchor.constraint(equalToConstant: 60),

            // Translated Label
            translatedLabel.topAnchor.constraint(equalTo: sourceTextView.bottomAnchor, constant: 16),
            translatedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            translatedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Translated Text View
            translatedTextView.topAnchor.constraint(equalTo: translatedLabel.bottomAnchor, constant: 4),
            translatedTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            translatedTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            translatedTextView.heightAnchor.constraint(equalToConstant: 80),

            // Activity Indicator (centered in translated text view area)
            activityIndicator.centerXAnchor.constraint(equalTo: translatedTextView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: translatedTextView.centerYAnchor),

            // Status Label
            statusLabel.topAnchor.constraint(equalTo: translatedTextView.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Done Button
            doneButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
            doneButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func loadSharedText() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            statusLabel.text = "No text found"
            activityIndicator.stopAnimating()
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
            statusLabel.text = "Unsupported content type"
            activityIndicator.stopAnimating()
            return
        }

        itemProvider.loadItem(forTypeIdentifier: targetType, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.statusLabel.text = "Error loading: \(error.localizedDescription)"
                    self.activityIndicator.stopAnimating()
                    return
                }

                guard let text = item as? String, !text.isEmpty else {
                    self.statusLabel.text = "Empty text"
                    self.activityIndicator.stopAnimating()
                    return
                }

                self.sourceTextView.text = text
                self.translate(text)
            }
        }
    }

    private func translate(_ text: String) {
        activityIndicator.startAnimating()
        statusLabel.text = "Translating..."

        TranslatorService.shared.translate(text) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.activityIndicator.stopAnimating()

                if result.hasPrefix("Error:") || result == "Parse error" || result == "No data" {
                    self.statusLabel.text = "Translation failed"
                    self.translatedTextView.text = result
                } else {
                    self.statusLabel.text = "Translation complete"
                    self.translatedTextView.text = result
                }
            }
        }
    }

    @objc private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

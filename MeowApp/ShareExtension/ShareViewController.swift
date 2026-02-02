#if canImport(UIKit)
import UIKit
import SwiftUI

class ShareViewController: UIViewController {
    private let viewModel = ShareViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let shareView = ShareView(
            viewModel: viewModel,
            onDismiss: { [weak self] in
                self?.extensionContext?.completeRequest(
                    returningItems: nil
                )
            }
        )

        let hostingVC = UIHostingController(rootView: shareView)
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            hostingVC.view.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),
            hostingVC.view.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            hostingVC.view.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            )
        ])
        hostingVC.didMove(toParent: self)

        Task {
            await viewModel.extractContent(
                from: extensionContext?.inputItems
                    as? [NSExtensionItem] ?? []
            )
        }
    }
}
#endif

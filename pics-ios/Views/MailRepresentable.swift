import Foundation
import SwiftUI
import MessageUI

struct MailRepresentable: UIViewControllerRepresentable {
    static let abuseEmail = "info@skogberglabs.com"
    let meta: PicMeta
    @Binding var showEmail: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(view: self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composeVC = MFMailComposeViewController()
        composeVC.mailComposeDelegate = context.coordinator
        
        // Configure the fields of the interface.
        composeVC.setToRecipients([MailRepresentable.abuseEmail])
        composeVC.setSubject("Objectionable content report")
        composeVC.setMessageBody("Objectionable content. Content ID: \(meta.key)", isHTML: false)
        return composeVC
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let view: MailRepresentable
        
        init(view: MailRepresentable) {
            self.view = view
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            view.showEmail.toggle()
        }
    }
    
    typealias UIViewControllerType = MFMailComposeViewController
}

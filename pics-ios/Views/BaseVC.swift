import Foundation
import UIKit

class BaseVC: UIViewController {
    private let log = LoggerFactory.shared.vc(BaseVC.self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PicsColors.uiBackground
        initUI()
    }
    
    func initUI() {
        
    }
}

//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import UIKit

class AlertService: NSObject {
    private let navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }
    func errorAlert(_ error: NSError) {
        let alert = UIAlertController(title: "error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        self.navigationController.present(alert, animated: true, completion: nil)
    }
}

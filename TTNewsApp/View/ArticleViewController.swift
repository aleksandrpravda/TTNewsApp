//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import UIKit
import CoreData

class ArticleViewController: UIViewController, NSFetchedResultsControllerDelegate {
    @IBOutlet var textView: UITextView!
    private var articleURL: String
    private var databaseService: DataBaseService
    
    lazy var fetchedResultsController: NSFetchedResultsController<Article> = {
        let fetchRequest = NSFetchRequest<Article>(entityName:"Article")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "url", ascending: true)]
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: appDelegate.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        controller.delegate = self
        do {
            try controller.performFetch()
        } catch {
            let nserror = error as NSError
            appDelegate.alertService?.errorAlert(nserror)
        }
        
        return controller
    }()
    
    init(databaseService: DataBaseService, url: String) {
        self.databaseService = databaseService
        self.articleURL = url
        super.init(nibName: "ArticleViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateText()
        self.databaseService.fetchArticle(url: self.articleURL) { error in
            if let error = error {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let nserror = error as NSError
                appDelegate.alertService?.errorAlert(nserror)
            }
        }
    }
    
    func updateText() {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        guard let article = self.fetchedResultsController.fetchedObjects?.first,
            let data = article.content,
            let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
                return
        }
        self.textView.attributedText = attributedString
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        updateText()
    }

}

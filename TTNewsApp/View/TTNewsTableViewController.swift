//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import UIKit
import CoreData

class TTNewsTableViewController: UITableViewController {
    private let databaseService: DataBaseService
    private var imagesDictionary = [String: Data]()
    
    lazy var fetchedResultsController: NSFetchedResultsController<Page> = {
        let fetchRequest = NSFetchRequest<Page>(entityName:"Page")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "number", ascending: true)]
        
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
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let nserror = error as NSError
            appDelegate.alertService?.errorAlert(nserror)
        }
        
        return controller
    }()
    
    init(databaseService: DataBaseService) {
        self.databaseService = databaseService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "News"
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(refreshWeatherData(_:)), for: .valueChanged)
        self.tableView.register(UINib(nibName: "NewsTableViewCell", bundle: nil), forCellReuseIdentifier: "NewsTableViewCellIdentifire")
        self.tableView.backgroundColor = UIColor.gray
        
        self.databaseService.fetchNews(page: 0) { error in
            if let error = error {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let nserror = error as NSError
                appDelegate.alertService?.errorAlert(nserror)
            }
        }
    }
    
    @objc private func refreshWeatherData(_ sender: Any) {
        self.databaseService.fetchNews(page: 0) {[weak self] error in
            if let error = error {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                let nserror = error as NSError
                appDelegate.alertService?.errorAlert(nserror)
            }
            self?.refreshControl?.endRefreshing()
        }
    }
    
    private func activityCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = UIColor.clear
        let actInd = UIActivityIndicatorView(style: .white)
        actInd.hidesWhenStopped = true;
        actInd.translatesAutoresizingMaskIntoConstraints = false
        actInd.startAnimating()
        cell.addSubview(actInd)
        
        let horizontalConstraint = NSLayoutConstraint(item: actInd, attribute: NSLayoutConstraint.Attribute.centerX, relatedBy: NSLayoutConstraint.Relation.equal, toItem: cell, attribute: NSLayoutConstraint.Attribute.centerX, multiplier: 1, constant: 0)
        let verticalConstraint = NSLayoutConstraint(item: actInd, attribute: NSLayoutConstraint.Attribute.centerY, relatedBy: NSLayoutConstraint.Relation.equal, toItem: cell, attribute: NSLayoutConstraint.Attribute.centerY, multiplier: 1, constant: 0)
        NSLayoutConstraint.activate([horizontalConstraint, verticalConstraint])
        return cell
    }
    
    private func publishDate(time: Double) -> String {
        let date = Date(timeIntervalSince1970: time)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = DateFormatter.Style.medium
        dateFormatter.dateStyle = DateFormatter.Style.medium
        dateFormatter.timeZone = .current
        return dateFormatter.string(from: date)
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let pages = self.fetchedResultsController.fetchedObjects!
        let page = pages[indexPath.section]
        if let document = page.documents?[indexPath.row] as? Document, let url = document.url {
            let articleViewController = ArticleViewController(databaseService: self.databaseService, url: url)
            articleViewController.navigationItem.title = document.title
            self.navigationController?.pushViewController(articleViewController, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let pages = self.fetchedResultsController.fetchedObjects {
            if indexPath.section >= pages.count {
                return 40
            }
        }
        return tableView.frame.size.width / 1.5
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard let objects = self.fetchedResultsController.fetchedObjects, objects.count > 0 else {
            return 0
        }
        return objects.count + 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let pages = self.fetchedResultsController.fetchedObjects {
            if section >= pages.count {
                return 1
            }
            return pages[section].documents?.count ?? 0
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let pages = self.fetchedResultsController.fetchedObjects {
            if section < pages.count {
                if let pageNumber = self.fetchedResultsController.fetchedObjects?[section].number {
                    return "#\(pageNumber + 1)"
                }
            }
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let pages = self.fetchedResultsController.fetchedObjects!
        if indexPath.section >= pages.count {
            self.databaseService.fetchNews(page: Int(pages.count)) { error in
                if let error = error {
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    let nserror = error as NSError
                    appDelegate.alertService?.errorAlert(nserror)
                }
            }
            return activityCell()
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "NewsTableViewCellIdentifire", for: indexPath) as! NewsTableViewCell
        let page = pages[indexPath.section]
        let sortedDocuments = page.documents?.sorted(by: { first, second in
            return (first as! Document).publishedAt < (second as! Document).publishedAt
        })
        let document = sortedDocuments?[indexPath.row] as! Document
        cell.typeLabel.text = document.tag?.name
        cell.titleLabel.text = document.title
        let timeResult = document.publishedAt
        cell.updateTimeLabel.text = publishDate(time: timeResult)
        cell.activityIndicator.hidesWhenStopped = true
        cell.thumbImageView.image = nil
        if let image = document.image, let url = image.wh_165_110_url {
            if let savedData = imagesDictionary[url], let image = UIImage(data: savedData) {
                cell.thumbImageView.image = image
            } else {
                cell.activityIndicator.startAnimating()
                self.databaseService.loadImage(url: url) { data, response, error in
                    if let error = error {
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        let nserror = error as NSError
                        appDelegate.alertService?.errorAlert(nserror)
                        return
                    }
                    if let responseUrl = response?.url, responseUrl.absoluteString.contains(url), let imageData = data {
                        print(responseUrl.absoluteString)
                        DispatchQueue.main.async {
                            cell.activityIndicator.stopAnimating()
                            self.imagesDictionary[url] = imageData
                            cell.thumbImageView.image = UIImage(data: imageData)
                        }
                    }
                }
            }
        }
        return cell
    }
}

extension TTNewsTableViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        tableView.reloadData()
    }
}

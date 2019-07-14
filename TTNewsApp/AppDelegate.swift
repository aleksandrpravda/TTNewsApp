//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var alertService: AlertService?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        print(paths[0])
        self.window = UIWindow(frame: UIScreen.main.bounds)
        
        if let window = self.window {
            let navigationController = UINavigationController()
            alertService = AlertService(navigationController: navigationController)
            window.rootViewController = navigationController
            let controller = TTNewsTableViewController(databaseService: CoreDataService(persistentContainer: self.persistentContainer, networkService: NetworkService()))
            navigationController.pushViewController(controller, animated: false)
            window.makeKeyAndVisible()
        }
        
        return true
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TTNewsApp")
        
        container.loadPersistentStores(completionHandler: { (_, error) in
            guard let error = error as NSError? else { return }
            fatalError("Unresolved error: \(error), \(error.userInfo)")
        })
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
}


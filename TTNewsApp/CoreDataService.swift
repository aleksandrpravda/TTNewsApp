//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import CoreData

class CoreDataService: DataBaseService {
    
    private let persistentContainer: NSPersistentContainer
    private let networkService: NetworkService
    
    required init(persistentContainer: NSPersistentContainer, networkService: NetworkService) {
        self.persistentContainer = persistentContainer
        self.networkService = networkService
    }
    
    func fetchNews(page: Int, completion: @escaping(Error?) -> Void) {
        self.networkService.news(by: page) { jsonDictionary, error in
            if let error = error {
                completion(error)
                return
            }
            
            guard let jsonDictionary = jsonDictionary else {
                let error = NSError(domain: "", code: -1, userInfo: nil)
                completion(error)
                return
            }
            
            let taskContext = self.persistentContainer.newBackgroundContext()
            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            taskContext.undoManager = nil
            //TODO add sync news
//            let success = self.syncCompanies(jsonDictionary: jsonDictionary, taskContext: taskContext)
//            var error: Error?
//            if !success {
//                error = NSError(domain: "", code: -2, userInfo: nil)
//            }
//            completion(error)
        }
    }
    
//    func updateCompany(by identifire: String, completion: @escaping(Error?) -> Void) {
//        self.webService.getCompanyDescription(companyId: identifire) { jsonDictionary, error in
//            if let error = error {
//                completion(error)
//                return
//            }
//
//            guard let jsonDictionary = jsonDictionary else {
//                let error = NSError(domain: "", code: -1, userInfo: nil)
//                completion(error)
//                return
//            }
//            let taskContext = self.persistentContainer.newBackgroundContext()
//            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//            taskContext.undoManager = nil
//
//            let success = self.updateDescription(jsonDictionary: jsonDictionary, taskContext: taskContext)
//            var error: Error?
//            if !success {
//                error = NSError(domain: "", code: -2, userInfo: nil)
//            }
//            completion(error)
//        }
//    }
    
    private func syncDocuments(pageNumber: Int, jsonDictionary: [String: Any], taskContext: NSManagedObjectContext) -> Bool {
        var successfull = false
        taskContext.performAndWait {
            let matchingCompaniesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Page")
            matchingCompaniesRequest.predicate = NSPredicate(format: "number in %@", argumentArray: [pageNumber])

            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: matchingCompaniesRequest)
            batchDeleteRequest.resultType = .resultTypeObjectIDs

            do {
                let batchDeleteResult = try taskContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
                if let deletedObjectIDs = batchDeleteResult?.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
                        into: [self.persistentContainer.viewContext])
                }
            } catch {
                print("Error: \(error)\nCould not batch delete existing records.")
                return
            }
            
            guard let page = NSEntityDescription.insertNewObject(forEntityName: "Page", into: taskContext) as? Page else {
                print("Error: Failed to create a new Company object!")
                return
            }
            let documentsJSON = jsonDictionary["documents"] as! [String: Any]
            let documents = NSSet()
            for documentKV in documentsJSON {
                guard let documentJSON = documentKV.value as? [String: Any] else {
                    continue
                }
                let document = Document()
                document.page = page
                
                if let tagJSON = documentJSON["tag"] as? [String: Any] {
                    let documentTag = Tag()
                    documentTag.document = document
                    documentTag.name = tagJSON["name"] as? String
                    documentTag.path = tagJSON["path"] as? String
                    document.tag = documentTag
                }
                
                document.withBanners = documentJSON["with_banners"] as? Bool ?? false
                document.version = documentJSON["version"] as? Int16 ?? 0
                document.title = documentJSON["title"] as? String
                
                
                documents.adding(document)
            }
            page.hasNext = jsonDictionary["has_next"] as! Bool
            page.collection = jsonDictionary["collection"] as? [String]
            page.documents = documents
            

//            for pageDictionary in jsonDictionary {
//
//
//
//
//                do {
////                    try page.update(with: companyDictionary)
//                } catch {
//                    print("Error: \(error)\nThe quake object will be deleted.")
//                    taskContext.delete(page)
//                }
//            }

            if taskContext.hasChanges {
                do {
                    try taskContext.save()
                } catch {
                    print("Error: \(error)\nCould not save Core Data context.")
                }
                taskContext.reset()
            }
            successfull = true
        }
        return successfull
    }
    
//    private func syncCompanies(jsonDictionary: [[String: Any]], taskContext: NSManagedObjectContext) -> Bool {
//        var successfull = false
//        taskContext.performAndWait {
//            let matchingCompaniesRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Company")
//            let companyIds = jsonDictionary.map { $0["id"] as? String }.compactMap { $0 }
//            matchingCompaniesRequest.predicate = NSPredicate(format: "id in %@", argumentArray: [companyIds])
//
//            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: matchingCompaniesRequest)
//            batchDeleteRequest.resultType = .resultTypeObjectIDs
//
//            do {
//                let batchDeleteResult = try taskContext.execute(batchDeleteRequest) as? NSBatchDeleteResult
//                if let deletedObjectIDs = batchDeleteResult?.result as? [NSManagedObjectID] {
//                    NSManagedObjectContext.mergeChanges(
//                        fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
//                        into: [self.persistentContainer.viewContext])
//                }
//            } catch {
//                print("Error: \(error)\nCould not batch delete existing records.")
//                return
//            }
//
//            for companyDictionary in jsonDictionary {
//                guard let company = NSEntityDescription.insertNewObject(forEntityName: "Company", into: taskContext) as? Company else {
//                    print("Error: Failed to create a new Company object!")
//                    return
//                }
//
//                do {
//                    try company.update(with: companyDictionary)
//                } catch {
//                    print("Error: \(error)\nThe quake object will be deleted.")
//                    taskContext.delete(company)
//                }
//            }
//
//            if taskContext.hasChanges {
//                do {
//                    try taskContext.save()
//                } catch {
//                    print("Error: \(error)\nCould not save Core Data context.")
//                }
//                taskContext.reset()
//            }
//            successfull = true
//        }
//        return successfull
//    }
//
//    private func updateDescription(jsonDictionary: [[String: Any]], taskContext: NSManagedObjectContext) -> Bool  {
//        var successfull = false
//        taskContext.performAndWait {
//            let dictionary = jsonDictionary.first!
////            let entityDescription = NSEntityDescription.entity(forEntityName: "Company", in: taskContext)
//
//            let companyId = dictionary["id"] as! String
//            let request = NSBatchUpdateRequest(entityName: "Company")
//            let predicate = NSPredicate(format: "id == %@", companyId)
//            request.predicate = predicate
//            let description = dictionary["description"] as! String
//            let id = dictionary["id"] as! String
//            let name = dictionary["name"] as! String
//            request.propertiesToUpdate = ["companyDescription": description, "id": id, "name": name]
//            request.resultType = .updatedObjectIDsResultType
//
//            do {
//                let result = try taskContext.execute(request) as! NSBatchUpdateResult
//                let objectIDArray = result.result as? [NSManagedObjectID]
//                let changes = [NSUpdatedObjectsKey : objectIDArray]
//                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable : Any], into: [self.persistentContainer.viewContext])
//            } catch {
//                fatalError("Failed to perform batch update: \(error)")
//            }
//
////            if taskContext.hasChanges {
//                do {
//                    try taskContext.save()
//                } catch {
//                    print("Error: \(error)\nCould not save Core Data context.")
//                }
//                taskContext.reset()
////            }
//            successfull = true
//        }
//        return successfull
//    }
}

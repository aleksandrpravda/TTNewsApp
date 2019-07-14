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
    
    func loadImage(url: String, completion: @escaping(Data?, URLResponse?, Error?) -> Void) {
        self.networkService.loadImage(url: url, completion: completion)
    }
    
    func fetchNews(page: Int, completion: @escaping(Error?) -> Void) {
        self.networkService.news(by: page) { jsonDictionary, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            guard let jsonDictionary = jsonDictionary else {
                let error = NSError(domain: "", code: -1, userInfo: nil)
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            let taskContext = self.persistentContainer.newBackgroundContext()
            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            taskContext.undoManager = nil
            let success = self.syncDocuments(pageNumber: page, jsonDictionary: jsonDictionary, taskContext: taskContext)
            var error: Error?
            if !success {
                error = NSError(domain: "", code: -2, userInfo: nil)
            }
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    func fetchArticle(url: String, completion: @escaping(Error?) -> Void) {
        self.networkService.news(by: url) { jsonDictionary, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            guard let jsonDictionary = jsonDictionary else {
                let error = NSError(domain: "", code: -1, userInfo: nil)
                DispatchQueue.main.async {
                    completion(error)
                }
                return
            }
            
            let taskContext = self.persistentContainer.newBackgroundContext()
            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            taskContext.undoManager = nil
            let success = self.syncArticle(url: url, jsonDictionary: jsonDictionary, taskContext: taskContext)
            var error: Error?
            if !success {
                error = NSError(domain: "", code: -2, userInfo: nil)
            }
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    private func syncArticle(url: String, jsonDictionary: [String: Any], taskContext: NSManagedObjectContext) -> Bool {
        var successfull = false
        taskContext.performAndWait {
            let matchingArticleRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Article")
            matchingArticleRequest.predicate = NSPredicate(format: "url == %@", url)
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: matchingArticleRequest)
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
            
            guard let _ = createArticle(from: jsonDictionary, in: taskContext) else {
                print("Error: Failed to create a new Article object!")
                return
            }
            
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
    
    private func syncDocuments(pageNumber: Int, jsonDictionary: [String: Any], taskContext: NSManagedObjectContext) -> Bool {
        var successfull = false
        taskContext.performAndWait {
            let matchingPageRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Page")
            if pageNumber > 0 {
                matchingPageRequest.predicate = NSPredicate(format: "number == %i", Int32(pageNumber))
            }
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: matchingPageRequest)
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
            
            guard let page = createPage(from: jsonDictionary, in: taskContext) else {
                print("Error: Failed to create a new Page object!")
                return
            }
            page.number = Int32(pageNumber)

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
    
    private func createArticle(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Article? {
        guard let article = NSEntityDescription.insertNewObject(forEntityName: "Article", into: taskContext) as? Article else {
            print("Error: Failed to create a new Article object!")
            return nil
        }
        let rootJSON = JSON["root"] as! [String: Any]
        article.title = rootJSON["title"] as? String
        article.secondTitle = rootJSON["second_title"] as? String
        article.documentType = rootJSON["document_type"] as? String
        article.version = rootJSON["version"] as? Int16 ?? Int16()
        article.desc = rootJSON["description"] as? String
        article.pushed = rootJSON["pushed"] as? Bool ?? false
        
        if let gallery = rootJSON["gallery"] as? [[String: Any]] {
            for pictureJSON in gallery {
                if let picture = createPicture(from: pictureJSON, in: taskContext) {
                    article.addToGallery(picture)
                }
            }
        }
        
        if let pictureJSON = rootJSON["one_picture"] as? [String: Any], let picture = createPicture(from: pictureJSON, in: taskContext) {
            picture.article = article
            article.onePicture = picture
        }
        
        if let contentJSON = rootJSON["content"] as? [String: Any] {
            article.layoutURL = contentJSON["layout_url"] as? String
            if let body = contentJSON["body"] as? String, let data = body.data(using: .utf8) {
                article.content = data
            }
        }
        if let sourceJSON = JSON["source"] as? [String: Any], let source = createSource(from: sourceJSON, in: taskContext) {
            source.article = article
            article.source = source
        }
        if let tagJSON = JSON["tag"] as? [String: Any], let tag = createTag(from: tagJSON, in: taskContext) {
            tag.article = article
            article.tag = tag
        }
        if let prefsJSON = JSON["prefs"] as? [String: Any] {
            if let outerJSON = prefsJSON["outer"] as? [String: Any], let outerPrefs = createPreference(from: outerJSON, in: taskContext) {
                outerPrefs.article = article
                article.addToPreferences(outerPrefs)
            }
            
            if let innerJSON = prefsJSON["inner"] as? [String: Any], let innerPrefs = createPreference(from: innerJSON, in: taskContext) {
                innerPrefs.article = article
                article.addToPreferences(innerPrefs)
            }
        }
        if let imageJSON = JSON["image"] as? [String: Any], let image = createImage(from: imageJSON, in: taskContext) {
            article.image = image
            image.article = article
        }
        return article
    }
    
    private func createPage(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Page? {
        guard let page = NSEntityDescription.insertNewObject(forEntityName: "Page", into: taskContext) as? Page else {
            print("Error: Failed to create a new Page object!")
            return nil
        }
        let documentsJSON = JSON["documents"] as! [String: Any]
        for documentKV in documentsJSON {
            guard let documentJSON = documentKV.value as? [String: Any],
                let document = createDocument(from: documentJSON, in: taskContext) else {
                    continue
            }
            document.page = page
            page.addToDocuments(document)
        }
        page.hasNext = JSON["has_next"] as? Bool ?? false
        page.collection = JSON["collection"] as? [String]
        return page
    }
    
    private func createDocument(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Document? {
        guard let document = NSEntityDescription.insertNewObject(forEntityName: "Document", into: taskContext) as? Document else {
            print("Error: Failed to create a new Document object!")
            return nil
        }
        if let tagJSON = JSON["tag"] as? [String: Any], let tag = createTag(from: tagJSON, in: taskContext) {
            tag.document = document
            document.tag = tag
        }
        
        if let sourceJSON = JSON["source"] as? [String: Any], let source = createSource(from: sourceJSON, in: taskContext) {
            source.document = document
            document.source = source
        }
        
        if let prefsJSON = JSON["prefs"] as? [String: Any] {
            if let outerJSON = prefsJSON["outer"] as? [String: Any], let outerPrefs = createPreference(from: outerJSON, in: taskContext) {
                outerPrefs.document = document
                document.addToPreferences(outerPrefs)
            }
            
            if let innerJSON = prefsJSON["inner"] as? [String: Any], let innerPrefs = createPreference(from: innerJSON, in: taskContext) {
                innerPrefs.document = document
                document.addToPreferences(innerPrefs)
            }
        }
        
        if let imageJSON = JSON["image"] as? [String: Any], let image = createImage(from: imageJSON, in: taskContext) {
            document.image = image
            image.document = document
        }
        document.withBanners = JSON["with_banners"] as? Bool ?? false
        document.version = JSON["version"] as? Int16 ?? Int16(0)
        document.url = JSON["url"] as? String
        document.title = JSON["title"] as? String
        document.secondTitle = JSON["second_title"] as? String
        document.publishedAt = JSON["published_at"] as? Double ?? Double(0)
        document.pushed = JSON["pushed"] as? Bool ?? false
        document.pubDate = JSON["pub_date"] as? String
        document.documentType = JSON["document_type"] as? String
        document.modifiedAt = JSON["modified_at"] as? Double ?? Double(0)
        document.full = JSON["full"] as? Bool ?? false
        document.fullWidth = JSON["full_width"] as? Bool ?? false
        return document
    }
    
    private func createPicture(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Picture? {
        guard let picture = NSEntityDescription.insertNewObject(forEntityName: "Picture", into: taskContext) as? Picture else {
            print("Error: Failed to create a new Image object!")
            return nil
        }
        picture.smallURL = JSON["small_url"] as? String
        picture.largeURL = JSON["large_url"] as? String
        picture.caption = JSON["caption"] as? String
        picture.credit = JSON["credit"] as? String
        picture.display = JSON["display"] as? String
        picture.originalWidth = JSON["original_width"] as? Double ?? Double()
        picture.originalHeight = JSON["original_height"] as? Double ?? Double()
        picture.actualHeight = JSON["actual_height"] as? Double ?? Double()
        picture.actualWidth = JSON["actual_width"] as? Double ?? Double()
        picture.retina = JSON["retina"] as? Bool ?? false
        return picture
    }
    
    private func createImage(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Image? {
        guard let image = NSEntityDescription.insertNewObject(forEntityName: "Image", into: taskContext) as? Image else {
            print("Error: Failed to create a new Image object!")
            return nil
        }
        image.caption = JSON["caption"] as? String
        image.credit = JSON["credit"] as? String
        image.display = JSON["display"] as? String
        image.show = JSON["show"] as? Bool ?? false
        image.originalWidth = JSON["original_width"] as? Double ?? Double()
        image.originalHeight = JSON["original_height"] as? Double ?? Double()
        image.wh_810_540_url = JSON["wh_810_540_url"] as? String
        image.wh_615_410_url = JSON["wh_615_410_url"] as? String
        image.wh_405_270_url = JSON["wh_405_270_url"] as? String
        image.wh_300_200_url = JSON["wh_300_200_url"] as? String
        image.wh_165_110_url = JSON["wh_165_110_url"] as? String
        image.wh_1245_710_url = JSON["wh_1245_710_url"] as? String
        image.wh_1245_500_url = JSON["wh_1245_500_url"] as? String
        image.small_url = JSON["small_url"] as? String
        image.large_url = JSON["large_url"] as? String
        image.elarge_url = JSON["elarge_url"] as? String
        return image
    }
    
    private func createSource(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Source? {
        guard let source = NSEntityDescription.insertNewObject(forEntityName: "Source", into: taskContext) as? Source else {
            print("Error: Failed to create a new Source object!")
            return nil
        }
        source.name = JSON["name"] as? String
        source.quote = JSON["quote"] as? String
        source.trust = JSON["trust"] as? Int16 ?? Int16(0)
        source.url = JSON["url"] as? String
        return source
    }
    
    private func createTag(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Tag? {
        guard let tag = NSEntityDescription.insertNewObject(forEntityName: "Tag", into: taskContext) as? Tag else {
            print("Error: Failed to create a new Tag object!")
            return nil
        }
        tag.name = JSON["name"] as? String
        tag.path = JSON["path"] as? String
        tag.show = JSON["show"] as? Bool ?? false
        return tag
    }
    
    private func createPreference(from JSON: [String: Any], in taskContext: NSManagedObjectContext) -> Preference? {
        guard let preference = NSEntityDescription.insertNewObject(forEntityName: "Preference", into: taskContext) as? Preference else {
            print("Error: Failed to create a new Preference object!")
            return nil
        }
        preference.layout = JSON["layout"] as? String
        if let elementsJSON = JSON["elements"] as? [String: Any] {
            if let innerTagJSON = elementsJSON["tag"] as? [String: Any] {
                guard let tag = createTag(from: innerTagJSON, in: taskContext) else {
                    print("Error: Failed to create a new Preference object!")
                    return nil
                }
                preference.tag = tag
                tag.preference = preference
            }
            if let adsJSON = elementsJSON["ads"] as? [String: Any] {
                preference.adsShow = adsJSON["show"] as? Bool ?? false
            }
            
            if let reactionsJSON = elementsJSON["reactions"] as? [String: Any] {
                preference.reactionsShow = reactionsJSON["show"] as? Bool ?? false
            }
            
            if let imageJSON = elementsJSON["image"] as? [String: Any] {
                guard let image = createImage(from: imageJSON, in: taskContext) else {
                    print("Error: Failed to create a new Preference object!")
                    return nil
                }
                preference.image = image
                image.preference = preference
            }
        }
        return preference
    }
}

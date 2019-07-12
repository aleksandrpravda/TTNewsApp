//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import CoreData

protocol DataBaseService {
    init(persistentContainer: NSPersistentContainer, networkService: NetworkService)
    func fetchNews(page: Int, completion: @escaping(Error?) -> Void)
//    func fetchCompanies(completion: @escaping(Error?) -> Void)
//    func updateCompany(by identifire: String, completion: @escaping(Error?) -> Void)
}

//
//  Copyright © 2019 aleksandrpravda. All rights reserved.
//

import CoreData

protocol DataBaseService {
    init(persistentContainer: NSPersistentContainer, networkService: NetworkService)
    func fetchNews(page: Int, completion: @escaping(Error?) -> Void)
    func fetchArticle(url: String, completion: @escaping(Error?) -> Void)
    func loadImage(url: String, completion: @escaping(Data?, URLResponse?, Error?) -> Void)
}

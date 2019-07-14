//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import Foundation

class NetworkService {
    private let meduzaUrl = "https://meduza.io/api/v3/"
    
    func news(by pageNumber: Int, completion: @escaping ([String: Any]?, Error?) -> Void)  {
        let langStr = Locale.current.languageCode!
        let url = URL(string: "\(self.meduzaUrl)search?chrono=news&page=\(pageNumber)&per_page=10&locale=\(langStr)")!
        makeRequest(by: url, completion: completion)
    }

    func news(by url: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: "\(self.meduzaUrl)\(url)")!
        makeRequest(by: url, completion: completion)
    }
    
    func loadImage(url: String, completion: @escaping(Data?, URLResponse?, Error?) -> Void) {
        let url = URL(string: "https://meduza.io\(url)")!
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }

    private func makeRequest(by url: URL, completion: @escaping ([String: Any]?, Error?) -> Void) {
        print("NetworkService::makeRequest::url \(url)")
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json; charset=UTF-8", forHTTPHeaderField: "Accept")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let _ = response {
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                        completion(json, nil)
                    } catch let error {
                        completion(nil, error)
                    }
                }
            } else {
                completion(nil, error)
            }
        }
        task.resume()
    }
}

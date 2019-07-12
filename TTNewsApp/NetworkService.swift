//
// Copyright © 2019 Alexander Rogachev. All rights reserved.
//

import Foundation

class NetworkService {
    
    func news(by pageNumber: Int, completion: @escaping ([String: Any]?, Error?) -> Void)  {
        let url = URL(string: "https://meduza.io/api/v3/search?chrono=news&page=\(pageNumber)&per_page=10&locale=ru")!
        makeRequest(by: url, completion: completion)
    }

    func news(by url: String, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let url = URL(string: url)!
        makeRequest(by: url, completion: completion)
    }

    private func makeRequest(by url: URL, completion: @escaping ([String: Any]?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json; charset=UTF-8", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let response = response {
                print(response)
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

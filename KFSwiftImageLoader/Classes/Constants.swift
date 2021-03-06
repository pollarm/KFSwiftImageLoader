//
//  Created by Kiavash Faisali on 10/2/16.
//
//

import Foundation

// MARK: - CompletionHolder Class
final internal class CompletionHolder {
    var completion: ((_ finished: Bool, _ error: NSError?) -> Void)?
    
    init(completion: ((_ finished: Bool, _ error: NSError?) -> Void)?) {
        self.completion = completion
    }
}

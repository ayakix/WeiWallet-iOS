//
//  String+Extension.swift
//  Wei
//
//  Created by yuzushioh on 2018/05/16.
//  Copyright © 2018 yz. All rights reserved.
//

import Foundation

extension String {
    func stripeEthereumPrefix() -> String {
        let address: String
        let prefix = "ethereum:"
        if hasPrefix(prefix) {
            address = String(dropFirst(prefix.count))
        } else {
            address = self
        }
        return address
    }
}

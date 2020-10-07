//
//  Contact.swift
//  IosCustomUiSdk
//
//  Created by apple on 10/5/20.
//  Copyright © 2020 Applozic. All rights reserved.
//

import Foundation
import MessageKit
// Contact class for MessageKit
struct Contact: SenderType, Equatable {
    var senderId: String
    var displayName: String
}

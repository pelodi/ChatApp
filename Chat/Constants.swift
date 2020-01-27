//
//  Constants.swift
//  Chat
//
//  Created by Pelo on 1/24/20.
//  Copyright © 2020 DTMobile. All rights reserved.
//

import Firebase

//nested struct
struct Constants {
    struct refs {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("chats")
    }
}

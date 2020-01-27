//
//  ChatViewController.swift
//  Chat
//
//  Created by Pelo on 1/24/20.
//  Copyright © 2020 DTMobile. All rights reserved.
//

import UIKit
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
    
    var messages = [JSQMessage]() //An array to display chat messages
    
    //Both proporties are lazy, which means they're only initialized once - when they're accessed. The bubble factory only creates bubbles once – saving resources.
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()

    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        //Create a temporary constant for the standard UserDefaults
        let defaults = UserDefaults.standard

        //Check if the keys jsq_id and jsq_name exist in the user defaults.
        if  let id = defaults.string(forKey: "jsq_id"),
            let name = defaults.string(forKey: "jsq_name")
        {
            //if they exist, assign the found id and name to senderId and senderDisplayName
            senderId = id
            senderDisplayName = name
        }
        else
        {
            //if they don't, assign a random numeric string to senderId and assign an empty string to senderDisplayName.
            senderId = String(arc4random_uniform(999999))
            senderDisplayName = ""

            //Save the new senderId in the user defaults, for key jsq_id and save the user defaults with synchronize().
            defaults.set(senderId, forKey: "jsq_id")
            defaults.synchronize()

            showDisplayNameDialog()
        }

        //Change the view controller title to "Chat: [display name]"
        title = "Chat: \(senderDisplayName!)"

        //Create a gesture recognizer that calls the function showDisplayNameDiaog() when the user taps the navigation bar.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDisplayNameDialog))
        tapGesture.numberOfTapsRequired = 1

        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        
        //The code above effetctively checks whether a display name and sender ID were previously set. If they weren't, it generates a random sender ID, and gives the user the opportunity to set a dipslay name.
        
        //The user can also change their display name at any point by tapping the navigation bar.
        
        //Two scenarios can happen. First, when a user starts the chat app for the first time, they get a random sender ID, and they're asked to input a sender display name. Second, when a user starts the app for a subsequent time, the app uses their previously set sender ID and display name. The user can optionally change their display name at a later point by tapping the navigation bar.
        
        inputToolbar.contentView.leftBarButtonItem = nil //hides the attachment button on the left of the chat text input field.
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero //set the avatar size to zero, again, hiding it.
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero //set the avatar size to zero, again, hiding it.
        
        //Create a query to get the last 10 chat messages
        let query = Constants.refs.databaseChats.queryLimited(toLast: 10)

        //Observe that query for newly added chat data, and call a closure when there's new data
        //There's some interaction between didPressSend() and observe(_:with:). When a new chat message typed and sent, it's returned via the observer function, and shown on screen.(That's why you didn't see chat messages before!)
        _ = query.observe(.childAdded, with: { [weak self] snapshot in
            
            //Inside the closure the data is "unpacked", a new JSQMessage object is created, and added to the end of the messages array.
            if  let data        = snapshot.value as? [String: String],
                let id          = data["sender_id"],
                let name        = data["name"],
                let text        = data["text"],
                !text.isEmpty
            {
                //New JSQMessage object is created. It's provided with the id, name and text from the data that's returned from Firebase.
                if let message = JSQMessage(senderId: id, displayName: name, text: text)
                {
                    self?.messages.append(message)

                    //This is called and JSQMVC refreshes the UI and shows the new message.
                    self?.finishReceivingMessage()
                }
            }
        })
    }
    
    @objc func showDisplayNameDialog()
    {
        let defaults = UserDefaults.standard

        let alert = UIAlertController(title: "Your Display Name", message: "Before you can chat, please choose a display name. Others will see this name when you send chat messages. You can change your display name again by tapping the navigation bar.", preferredStyle: .alert)

        alert.addTextField { textField in

            if let name = defaults.string(forKey: "jsq_name")
            {
                textField.text = name
            }
            else
            {
                let names = ["Ford", "Arthur", "Zaphod", "Trillian", "Slartibartfast", "Humma Kavula", "Deep Thought"]
                textField.text = names[Int(arc4random_uniform(UInt32(names.count)))]
            }
        }

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] _ in

            if let textField = alert?.textFields?[0], !textField.text!.isEmpty {

                self?.senderDisplayName = textField.text

                self?.title = "Chat: \(self!.senderDisplayName!)"

                defaults.set(textField.text, forKey: "jsq_name")
                defaults.synchronize()
            }
        }))

        present(alert, animated: true, completion: nil)
    }
    
    //JSQMVC needs access to the data from messages in order to show those message bubbles.
    //These override delegate methods are called when JSQMVC needs.
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        //returns an item from messages based on the index from indexPath.item, effectively returning the message data for a particular message by its index.
        return messages[indexPath.item]
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //returns the total number of messages, based on messages.count - the amount of items in array.
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        // when messages[indexPath.item].senderId == senderId is true, return outgoingBubble
        // when that expression is false, return incomingBubble
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        //this function returns nil when JSQMVC wants avatar image data, effectively hiding the avatars.
        return nil
    }
    
    //This is called when the label text is needed.
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }

    //This is called when the height of the top label is needed.
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        //Logically, if the current user sent the message, you don't have to show their sender name, so the label stays empty and hidden.
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        //create a reference to a new value, in Firebase, on the /chats node, using childByAutoId()
        //childByAutoId() will generate a unique key.
        let ref = Constants.refs.databaseChats.childByAutoId()

        //create a dictionary called message that contains all the information about the to-be-sent message: sender ID, display name, chat text
        let message = ["sender_id": senderId, "name": senderDisplayName, "text": text]

        //set the reference to the value - store the dictionary in the newly created node
        ref.setValue(message)

        //a function that tells JSQMVC you're done
        finishSendingMessage()
    }
}


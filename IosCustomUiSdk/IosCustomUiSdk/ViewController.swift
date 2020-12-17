//
//  ViewController.swift
//  IosCustomUiSdk
//
//  Created by apple on 27/09/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Applozic
import UIKit

class ViewController: UIViewController {
    let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
    @IBOutlet var unreadConversationsLabel: UILabel!
    override func viewDidAppear(_: Bool) {}

    override func viewWillAppear(_: Bool) {
        unreadConversationsLabel.text = ""
        getUnreadConversationsCount { count in
            self.unreadConversationsLabel.text = "Unread conversations count : \(count)"
        }
    }

    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(newMessageReceived(notification:)), name: Notification.Name(Constants.NotificationsName.DidRecieveNewMessageNotification), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func logoutAction(_: UIButton) {
        let registerUserClientService = ALRegisterUserClientService()
        registerUserClientService.logout { _, _ in
            if !UIApplication.shared.isRegisteredForRemoteNotifications {
                UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                    DispatchQueue.main.async {
                        self.dismiss(animated: false, completion: nil)
                    }
                }
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    @IBAction func launchChatList(_: UIButton) {
        let viewController = ConversationListViewController()
        let nav = ALKBaseNavigationViewController(rootViewController: viewController)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }

    @objc open func newMessageReceived(notification _: NSNotification) {
        getUnreadConversationsCount { count in
            self.unreadConversationsLabel.text = "Unread conversations count : \(count)"
        }
    }

    // Unread conversations count
    func getUnreadConversationsCount(completion: @escaping (Int) -> Void) {
        appDelegate?.applozicClient.getLatestMessages(false, withCompletionHandler: { messageList, error in
            if error == nil {
                guard let list = messageList else {
                    return
                }
                var count = 0
                let contactService = ALContactService()
                let channelService = ALChannelService()

                for message in list as! [ALMessage] {
                    if message.groupId == nil {
                        // unread conversation for one to one chat
                        let contact = contactService.loadContact(byKey: "userId", value: message.to)
                        if contact?.unreadCount as! Int > 0 {
                            count += 1
                        }
                    } else {
                        // unread conversation for channel or group
                        let channel = channelService.getChannelByKey(message.groupId)
                        if channel?.unreadCount as! Int > 0 {
                            count += 1
                        }
                    }
                }
                print("Unread conversations count is : ", count)
                completion(count)
            } else {
                print("Failed to get the unread count")
                completion(0)
            }
        })
    }
}

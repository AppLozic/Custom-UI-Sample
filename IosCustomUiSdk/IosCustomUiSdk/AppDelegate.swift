//
//  AppDelegate.swift
//  IosCustomUiSdk
//
//  Created by apple on 27/09/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Applozic
import UIKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, ApplozicUpdatesDelegate, UNUserNotificationCenterDelegate {
    public var applozicClient = ApplozicClient()
    let pushAssist = ALPushAssist()

    public var userId: String?
    public var groupId: NSNumber = 0
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        registerForNotification()

        applozicClient = ApplozicClient(applicationKey: "applozic-sample-app", with: self)

        if ALUserDefaultsHandler.isLoggedIn() {
            let viewController = ConversationListViewController()
            let nav = ALKBaseNavigationViewController(rootViewController: viewController)
            nav.modalTransitionStyle = .crossDissolve
            nav.modalPresentationStyle = .fullScreen
            window?.makeKeyAndVisible()
            window?.rootViewController!.present(nav, animated: true, completion: nil)
        }

        if launchOptions != nil {
            let dictionary = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? NSDictionary

            if dictionary != nil {
                let pushnotification = ALPushNotificationService()

                if pushnotification.isApplozicNotification(launchOptions) {
                    applozicClient.notificationArrived(to: application, with: launchOptions)
                    DispatchQueue.main.async {
                        self.openChatView(dic: dictionary as! [AnyHashable: Any])
                    }

                } else {
                    // handle your notification
                }
            }
        }
        // Override point for customization after application launch.
        return true
    }

    func registerForNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { granted, _ in

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationWillResignActive(_: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        applozicClient.unsubscribeToConversation()
    }

    func applicationWillEnterForeground(_: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background
    }

    func applicationDidBecomeActive(_: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        ALMessageService.getLatestMessage(forUser: ALUserDefaultsHandler.getDeviceKeyString(), with: self) { _, _ in
        }

        applozicClient.subscribeToConversation()
    }

    func applicationWillTerminate(_: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        ALDBHandler.sharedInstance().saveContext()
    }

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NSLog("Device token data :: \(deviceToken.description)")

        var deviceTokenString: String = ""
        for i in 0 ..< deviceToken.count {
            deviceTokenString += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }

        NSLog("Device token :: \(deviceTokenString)")

        if ALUserDefaultsHandler.getApnDeviceToken() != deviceTokenString {
            let alRegisterUserClientService = ALRegisterUserClientService()
            alRegisterUserClientService.updateApnDeviceToken(withCompletion: deviceTokenString, withCompletion: {
                _, error in
                if error != nil {}

            })
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let applozicPushNotification = ALPushNotificationService()

        if !applozicPushNotification.isApplozicNotification(notification.request.content.userInfo) {
            completionHandler([.alert, .sound])
        }

        // Play sound and show alert to the user
    }

    func userNotificationCenter(_: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void)
    {
        // Determine the user action

        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            print("Dismiss Action")
        case UNNotificationDefaultActionIdentifier:
            print("Default")
        case "Snooze":
            print("Snooze")
        case "Delete":
            print("Delete")
        default:
            print("Unknown action")
        }

        applozicClient.notificationArrived(to: UIApplication.shared, with: response.notification.request.content.userInfo)

        let pushNotification = ALPushNotificationService()
        let alPushAssist = ALPushAssist()

        if pushNotification.isApplozicNotification(response.notification.request.content.userInfo) {
            openChatView(dic: response.notification.request.content.userInfo)
        } else {
            let userInfo = response.notification.request.content.userInfo

            if alPushAssist.topViewController is ConversationViewController {
                var json = [String: Any]()

                if let userId = userInfo["userId"] as? String {
                    json = ["userId": userId]
                    json["groupId"] = 0
                } else {
                    let groupId = userInfo["groupId"] as? NSNumber
                    json = ["groupId": groupId]
                }

                NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadData"), object: json)
            } else {
                let viewController = ConversationViewController()

                let userId = userInfo["userId"] as? String
                if userId != nil {
                    viewController.userId = userId
                } else {
                    let groupId = userInfo["groupId"] as? NSNumber
                    viewController.groupId = groupId
                }
                alPushAssist.topViewController.navigationController?.pushViewController(viewController, animated: true)
            }
        }

        completionHandler()
    }

    func sendLocalPush(message: ALMessage) {
        let center = UNUserNotificationCenter.current()

        let contactService = ALContactDBService()
        let channelService = ALChannelService()
        UNUserNotificationCenter.current().delegate = self

        var title = String()

        if message.groupId != nil, message.groupId != 0 {
            let alChannel = channelService.getChannelByKey(message.groupId)

            guard let channel = alChannel,!channel.isNotificationMuted() else {
                return
            }

            title = channel.name
        } else {
            let alContact = contactService.loadContact(byKey: "userId", value: message.to)

            guard let contact = alContact else {
                return
            }
            title = contact.displayName != nil ? contact.displayName : contact.userId
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message.message
        content.sound = UNNotificationSound.default

        var dict = [AnyHashable: Any]()
        if let groupId = message.groupId,
            message.groupId != 0
        {
            dict = ["groupId": groupId]
        } else if let userId = message.to {
            dict = ["userId": userId]
        }

        content.userInfo = dict

        let identifier = "ApplozicLocalNotification"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        center.add(request, withCompletionHandler: { error in

            if error != nil {
                // Something went wrong
            }

        })
    }

    func onMessageReceived(_ alMessage: ALMessage!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onMessageReceived(alMessage)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onMessageReceived(alMessage)
        }
    }

    func onMessageSent(_ alMessage: ALMessage!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onMessageSent(alMessage)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onMessageSent(alMessage)
        }
    }

    func onUserDetailsUpdate(_ userDetail: ALUserDetail!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onUserDetailsUpdate(userDetail)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onUserDetailsUpdate(userDetail)
        }
    }

    func onMessageDelivered(_ message: ALMessage!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onMessageDelivered(message)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onMessageDelivered(message)
        }
    }

    func onMessageDeleted(_ messageKey: String!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onMessageDeleted(messageKey)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onMessageDeleted(messageKey)
        }
    }

    func onMessageDeliveredAndRead(_ message: ALMessage!, withUserId userId: String!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onMessageDeliveredAndRead(message, withUserId: userId)

        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onMessageDeliveredAndRead(message, withUserId: userId)
        }
    }

    func onConversationDelete(_ userId: String!, withGroupId groupId: NSNumber!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onConversationDelete(userId, withGroupId: groupId)

        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onConversationDelete(userId, withGroupId: groupId)
        }
    }

    func conversationRead(byCurrentUser userId: String!, withGroupId groupId: NSNumber!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.conversationRead(byCurrentUser: userId, withGroupId: groupId)

        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.conversationRead(byCurrentUser: userId, withGroupId: groupId)
        }
    }

    func onUpdateTypingStatus(_ userId: String!, status: Bool) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onUpdateTypingStatus(userId, status: status)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onUpdateTypingStatus(userId, status: status)
        }
    }

    func onUpdateLastSeen(atStatus alUserDetail: ALUserDetail!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onUpdateLastSeen(atStatus: alUserDetail)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onUpdateLastSeen(atStatus: alUserDetail)
        }
    }

    func onUserBlockedOrUnBlocked(_ userId: String!, andBlockFlag flag: Bool) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onUserBlockedOrUnBlocked(userId, andBlockFlag: flag)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onUserBlockedOrUnBlocked(userId, andBlockFlag: flag)
        }
    }

    func onChannelUpdated(_ channel: ALChannel!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onChannelUpdated(channel)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onChannelUpdated(channel)
        }
    }

    func onAllMessagesRead(_ userId: String!) {
        if pushAssist.topViewController is ConversationListViewController {
            let viewController = pushAssist.topViewController as? ConversationListViewController
            viewController?.onAllMessagesRead(userId)
        } else if pushAssist.topViewController is ConversationViewController {
            let viewController = pushAssist.topViewController as? ConversationViewController
            viewController?.onAllMessagesRead(userId)
        }
    }

    func onMqttConnectionClosed() {
        applozicClient.subscribeToConversation()
    }

    func onMqttConnected() {}

    func onUserMuteStatus(_: ALUserDetail!) {}

    func onChannelMute(_: NSNumber!) {}

    func openChatView(dic: [AnyHashable: Any]) {
        let alPushAssist = ALPushAssist()
        let type = dic["AL_KEY"] as? String
        let alValueJson = dic["AL_VALUE"] as? String

        let data: Data? = alValueJson?.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))

        var theMessageDict: [AnyHashable: Any]?
        do {
            if let aData = data {
                theMessageDict = try JSONSerialization.jsonObject(with: aData, options: []) as? [AnyHashable: Any]
            }

            let notificationMsg = theMessageDict?["message"] as? String

            if type != nil {
                let myArray = notificationMsg!.components(separatedBy: CharacterSet(charactersIn: ":"))

                var channelKey: NSNumber = 0

                if myArray.count > 2 {
                    if let key = Int(myArray[1]) {
                        channelKey = NSNumber(value: key)
                    }
                } else {
                    channelKey = 0
                }

                if alPushAssist.topViewController is ConversationViewController {
                    var json = [String: Any]()

                    if channelKey != 0 {
                        json["groupId"] = channelKey
                    } else {
                        json["userId"] = notificationMsg
                        json["groupId"] = 0
                    }

                    NotificationCenter.default.post(name: Notification.Name(rawValue: "reloadData"), object: json)

                } else {
                    let viewController = ConversationViewController()

                    if channelKey != 0 {
                        viewController.groupId = channelKey
                    } else {
                        viewController.userId = notificationMsg
                    }

                    alPushAssist.topViewController.navigationController?.pushViewController(viewController, animated: true)
                }
            }
        } catch {
            print("Error while opening the chat view %@", error.localizedDescription)
        }
    }
}

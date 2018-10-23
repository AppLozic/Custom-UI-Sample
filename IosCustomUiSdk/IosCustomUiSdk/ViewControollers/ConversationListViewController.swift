//
//  MessagesViewController.swift
//  IosCustomUiSdk
//
//  Created by Sunil on 27/09/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Foundation
import UIKit
import MessageKit
import MapKit
import Applozic

public class ConversationListViewController: UIViewController, UITableViewDelegate, ApplozicUpdatesDelegate, UITableViewDataSource {

    let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate

    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)

    fileprivate let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.estimatedRowHeight = 75
        tv.rowHeight = 75
        tv.separatorStyle = .none
        tv.backgroundColor = UIColor.white
        tv.keyboardDismissMode = .onDrag
        return tv
    }()


    var allMessages = [ALMessage]()

    var applozicClient = ApplozicClient();

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allMessages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell: MessageCell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell

        guard let alMessage = allMessages[indexPath.row] as? ALMessage else {
            return UITableViewCell()
        }

        cell.update(viewModel: alMessage)
        return cell;
    }


    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        guard let alMessage = allMessages[indexPath.row] as? ALMessage else {
            return
        }

        let viewController = ConversationViewController()

        if(alMessage.groupId != nil && alMessage.groupId != 0) {
            viewController.groupId = alMessage.groupId;
        } else {
            viewController.userId = alMessage.to;
        }
        viewController.createdAtTime = alMessage.createdAtTime
        self.navigationController?.pushViewController(viewController, animated: true)
    }



    public override func viewWillAppear(_ animated: Bool) {

        self.setupView()

    }

    public override func viewDidAppear(_ animated: Bool) {

        activityIndicator.center = CGPoint(x: view.bounds.size.width/2, y: view.bounds.size.height/2)
        activityIndicator.color = UIColor.gray
        view.addSubview(activityIndicator)
        self.view.bringSubview(toFront: activityIndicator)
        self.activityIndicator.startAnimating()

        applozicClient = ApplozicClient.init(applicationKey: "applozic-sample-app", with: self)
        applozicClient.subscribeToConversation()

        applozicClient.getLatestMessages(false, withCompletionHandler: { messageList, error in
            if error == nil {
                self.allMessages = messageList as! [ALMessage];
                self.activityIndicator.stopAnimating()
                self.tableView.reloadData()

            }
        })
    }

    private func setupView() {

        title = "My Chats"

        let back = NSLocalizedString("Back", value: "Back", comment: "")
        let leftBarButtonItem = UIBarButtonItem(title: back, style: .plain, target: self, action: #selector(customBackAction))


        navigationItem.leftBarButtonItem = leftBarButtonItem

        self.addViewsForAutolayout(views: [tableView])

        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true

        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        self.automaticallyAdjustsScrollViewInsets = false
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")

    }

    @objc func customBackAction() {
        guard let nav = self.navigationController else { return }
        let dd = nav.popViewController(animated: true)
        if dd == nil {
            self.dismiss(animated: true, completion: nil)
        }
    }


    func addViewsForAutolayout(views: [UIView]) {
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(view)
        }
    }


    public override func viewWillDisappear(_ animated: Bool) {
        applozicClient .unsubscribeToConversation()

    }


    deinit {

    }


    public func onMessageReceived(_ alMessage: ALMessage!) {

        self .addMessage(alMessage)
    }

    public func onMessageSent(_ alMessage: ALMessage!) {

        self .addMessage(alMessage)

    }

    public func onUserDetailsUpdate(_ userDetail: ALUserDetail!) {

    }

    public func onMessageDelivered(_ message: ALMessage!) {



    }

    public func onMessageDeleted(_ messageKey: String!) {

    }

    public func onMessageDeliveredAndRead(_ message: ALMessage!, withUserId userId: String!) {

    }

    public func onConversationDelete(_ userId: String!, withGroupId groupId: NSNumber!) {



    }

    public func conversationRead(byCurrentUser userId: String!, withGroupId groupId: NSNumber!) {
        //  NotificationCenter.default.post(name: Notification.Name(rawValue: "Unread_Conversation_Read"), object: infoDict)

    }

    public func onUpdateTypingStatus(_ userId: String!, status: Bool) {
        //    NotificationCenter.default.post(name: Notification.Name(rawValue: "GenericRichListButtonSelected"), object: infoDict)

    }

    public func onUpdateLastSeen(atStatus alUserDetail: ALUserDetail!) {
        // NotificationCenter.default.post(name: Notification.Name(rawValue: "Online_Status_Update"), object: alUserDetail)

    }

    public func onUserBlockedOrUnBlocked(_ userId: String!, andBlockFlag flag: Bool) {
        //    NotificationCenter.default.post(name: Notification.Name(rawValue: "GenericRichListButtonSelected"), object: infoDict)

    }

    public func onChannelUpdated(_ channel: ALChannel!) {
        //NotificationCenter.default.post(name: Notification.Name(rawValue: "Channel_Info_Sync"), object: channel)

    }

    public func onAllMessagesRead(_ userId: String!) {

        //  NotificationCenter.default.post(name: Notification.Name(rawValue: "All_Messages_Read"), object: userId)

    }

    public func onMqttConnectionClosed() {

        applozicClient.subscribeToConversation()

    }

    public func onMqttConnected() {

    }


    public func addMessage(_ alMessage: ALMessage) {
        appDelegate?.sendLocalPush(message: alMessage)
        var messagePresent = [ALMessage]()
        if let _ = alMessage.groupId {
            messagePresent = allMessages.filter { ($0.groupId != nil) ? $0.groupId == alMessage.groupId: false }
        } else {
            messagePresent = allMessages.filter { ($0.contactIds != nil) ? $0.contactIds == alMessage.contactIds: false }
        }

        if let firstElement = messagePresent.first, let index = allMessages.index(of: firstElement) {
            allMessages[index] = alMessage
            self.allMessages[index] = alMessage
        } else {
            self.allMessages.append(alMessage)
        }

        if (self.allMessages.count) > 1 {
            self.allMessages = allMessages.sorted { ($0.createdAtTime != nil && $1.createdAtTime != nil) ? Int(truncating: $0.createdAtTime) > Int(truncating: $1.createdAtTime): false }
        }

        self.tableView.reloadData()

    }

}


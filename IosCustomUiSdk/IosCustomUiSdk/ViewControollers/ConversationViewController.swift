//
//  ConversationViewController.swift
//  IosCustomUiSdk
//
//  Created by Sunil on 02/10/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Applozic
import Foundation
import InputBarAccessoryView
import MapKit
import MessageKit
import UIKit

public class ConversationViewController: MessagesViewController {
    private(set) lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(loadMoreMessages), for: .valueChanged)
        return control
    }()

    // let refreshControl = UIRefreshControl()
    let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
    let activityIndicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)

    public var userId: String?
    public var groupId: NSNumber?
    var createdAtTime: NSNumber?
    var contact: ALContact?
    var channel: ALChannel?
    var messageList: [Message] = []
    var isTyping = false

    lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.center = CGPoint(x: view.bounds.size.width / 2, y: view.bounds.size.height / 2)
        activityIndicator.color = UIColor.gray
        view.addSubview(activityIndicator)
        view.bringSubviewToFront(activityIndicator)
        loadMessages()
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
        messagesCollectionView.refreshControl = refreshControl
    }

    func loadMessages() {
        var chatId: String?
        let req = MessageListRequest()
        if groupId != nil, groupId != 0 {
            req.channelKey = groupId // pass groupId
            chatId = groupId?.stringValue
        } else {
            req.userId = userId // pass userId
            chatId = userId
        }
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
            self.messagesCollectionView.isUserInteractionEnabled = false
        }

        if ALUserDefaultsHandler.isServerCallDone(forMSGList: chatId) {
            ALMessageService.getMessageList(forContactId: req.userId, isGroup: req.channelKey != nil, channelKey: req.channelKey, conversationId: nil, start: 0, withCompletion: {
                messages in
                guard let messages = messages else {
                    return
                }
                NSLog("messages loaded: %@", messages)
                for alMessage in messages {
                    self.convertMessageToMockMessage(_alMessage: alMessage as! ALMessage)
                }

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.messagesCollectionView.isUserInteractionEnabled = true
                    self.messagesCollectionView.reloadData()
                    self.messagesCollectionView.scrollToBottom()
                }
                self.markConversationAsRead()
            })
        } else {
            appDelegate?.applozicClient.getMessages(req) { messageList, error in

                guard error == nil, let newMessages = messageList as? [ALMessage] else {
                    return
                }

                for alMessage in newMessages {
                    self.convertMessageToMockMessage(_alMessage: alMessage)
                }

                self.messageList = self.messageList.reversed()
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.messagesCollectionView.isUserInteractionEnabled = true
                    self.messagesCollectionView.reloadData()
                    self.messagesCollectionView.scrollToBottom()
                }
                self.markConversationAsRead()
            }
        }
    }

    func setTitle() {
        if groupId != nil, groupId != 0 {
            let alChannelService = ALChannelService()
            alChannelService.getChannelInformation(byResponse: groupId, orClientChannelKey: nil, withCompletion: { _, alChannel, _ in

                if alChannel != nil {
                    self.channel = alChannel
                    self.title = alChannel?.name != nil ? alChannel?.name : "NO name"
                }

            })
        } else {
            let contactDataBase = ALContactDBService()
            contact = contactDataBase.loadContact(byKey: "userId", value: userId)
            title = contact?.displayName != nil ? contact?.displayName : contact?.userId
        }
    }

    @objc func loadMoreMessages() {
        let messagelist = MessageListRequest()

        if groupId != nil, groupId != 0 {
            messagelist.channelKey = groupId // pass groupId
        } else {
            messagelist.userId = userId // pass userId
        }

        messagelist.endTimeStamp = messageList[0].createdAtTime

        appDelegate?.applozicClient.getMessages(messagelist, withCompletionHandler: { messageList, error in
            if error == nil {
                guard error == nil, let newMessages = messageList as? [ALMessage] else {
                    return
                }

                var messageArray: [Message] = []

                for alMessage in newMessages {
                    switch Int32(alMessage.contentType) {
                    case ALMESSAGE_CONTENT_DEFAULT:

                        var mockTextMessage = Message(text: alMessage.message ?? "", sender: self.getSender(message: alMessage), messageId: alMessage.key, date: Date(timeIntervalSince1970: Double(alMessage.createdAtTime.doubleValue / 1000)))
                        mockTextMessage.createdAtTime = alMessage.createdAtTime
                        messageArray.append(mockTextMessage)

                    case ALMESSAGE_CONTENT_LOCATION:

                        do {
                            let objectData: Data? = alMessage.message.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                            var jsonStringDic: [AnyHashable: Any]?

                            if let aData = objectData {
                                jsonStringDic = try JSONSerialization.jsonObject(with: aData, options: .mutableContainers) as? [AnyHashable: Any]
                            }

                            let latDelta: CLLocationDegrees = Double(jsonStringDic?["lat"] as! String) ?? 0.0

                            let lonDelta: CLLocationDegrees = Double(jsonStringDic?["lon"] as! String) ?? 0.0

                            let location = CLLocation(latitude: latDelta, longitude: lonDelta)

                            let date = Date(timeIntervalSince1970: Double(alMessage.createdAtTime.doubleValue / 1000))

                            var mockLocationMessage = Message(location: location, sender: self.getSender(message: alMessage), messageId: alMessage.key, date: date)
                            mockLocationMessage.createdAtTime = alMessage.createdAtTime

                            messageArray.append(mockLocationMessage)
                        } catch {
                            print("Error while building location message ", error.localizedDescription)
                        }

                    default:
                        break
                    }
                }

                DispatchQueue.main.async {
                    self.messageList.insert(contentsOf: messageArray, at: 0)
                    self.messagesCollectionView.reloadDataAndKeepOffset()
                    self.refreshControl.endRefreshing()
                }
            }
        })
    }

    @objc func handleKeyboardButton() {
        messageInputBar.inputTextView.resignFirstResponder()
        let actionSheetController = UIAlertController(title: "Change Keyboard Style", message: nil, preferredStyle: .actionSheet)
        let actions = [
            UIAlertAction(title: "Slack", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    self.slack()
                }
            }),
            UIAlertAction(title: "iMessage", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    self.iMessage()
                }
            }),
            UIAlertAction(title: "Default", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    self.defaultStyle()
                }
            }),
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil),
        ]
        actions.forEach { actionSheetController.addAction($0) }
        actionSheetController.view.tintColor = UIColor(red: 66.0 / 255, green: 173.0 / 255, blue: 247.0 / 255, alpha: 1)
        present(actionSheetController, animated: true, completion: nil)
    }

    // MARK: - Keyboard Style

    func slack() {
        defaultStyle()
        messageInputBar.inputTextView.placeholder = "Type a message..."
        messageInputBar.backgroundView.backgroundColor = .white
        messageInputBar.isTranslucent = false
        messageInputBar.inputTextView.backgroundColor = .clear
        messageInputBar.inputTextView.layer.borderWidth = 0
        let items = [
            makeButton(named: "ic_camera").onTextViewDidChange { button, textView in
                button.isEnabled = textView.text.isEmpty
            },
            makeButton(named: "ic_at").onSelected {
                $0.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
            },
            makeButton(named: "ic_hashtag").onSelected {
                $0.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
            },
            .flexibleSpace,
            makeButton(named: "ic_library").onTextViewDidChange { button, textView in
                button.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
                button.isEnabled = textView.text.isEmpty
            },
            messageInputBar.sendButton
                .configure {
                    $0.layer.cornerRadius = 8
                    $0.layer.borderWidth = 1.5
                    $0.layer.borderColor = $0.titleColor(for: .disabled)?.cgColor
                    $0.setTitleColor(.white, for: .normal)
                    $0.setTitleColor(.white, for: .highlighted)
                    $0.setSize(CGSize(width: 52, height: 30), animated: true)
                }.onDisabled {
                    $0.layer.borderColor = $0.titleColor(for: .disabled)?.cgColor
                    $0.backgroundColor = .white
                }.onEnabled {
                    $0.backgroundColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
                    $0.layer.borderColor = UIColor.clear.cgColor
                }.onSelected {
                    // We use a transform becuase changing the size would cause the other views to relayout
                    $0.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }.onDeselected {
                    $0.transform = CGAffineTransform.identity
                },
        ]
        items.forEach { $0.tintColor = .lightGray }

        // We can change the container insets if we want
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)

        // Since we moved the send button to the bottom stack lets set the right stack width to 0
        messageInputBar.setRightStackViewWidthConstant(to: 0, animated: true)

        // Finally set the items
        messageInputBar.setStackViewItems(items, forStack: .bottom, animated: true)
    }

    func iMessage() {
        defaultStyle()
        messageInputBar.inputTextView.placeholder = "Type a message..."
        messageInputBar.isTranslucent = false
        messageInputBar.backgroundView.backgroundColor = .white
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.backgroundColor = UIColor(red: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1)
        messageInputBar.inputTextView.placeholderTextColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 36)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 36)
        messageInputBar.inputTextView.layer.borderColor = UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 1).cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 16.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        messageInputBar.setRightStackViewWidthConstant(to: 36, animated: true)
        messageInputBar.setStackViewItems([messageInputBar.sendButton], forStack: .right, animated: true)
        messageInputBar.sendButton.imageView?.backgroundColor = UIColor(red: 66.0 / 255, green: 173.0 / 255, blue: 247.0 / 255, alpha: 1)
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        messageInputBar.sendButton.setSize(CGSize(width: 36, height: 36), animated: true)
        messageInputBar.sendButton.image = #imageLiteral(resourceName: "ic_up")
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.imageView?.layer.cornerRadius = 16
        messageInputBar.sendButton.backgroundColor = .clear
        messageInputBar.middleContentViewPadding.right = -38
    }

    func defaultStyle() {
        let newMessageInputBar = InputBarAccessoryView()
        newMessageInputBar.sendButton.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
        newMessageInputBar.delegate = self
        messageInputBar = newMessageInputBar
        reloadInputViews()
    }

    // MARK: - Helpers

    func makeButton(named: String) -> InputBarButtonItem {
        return InputBarButtonItem()
            .configure {
                $0.spacing = .fixed(10)
                $0.image = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
                $0.setSize(CGSize(width: 30, height: 30), animated: true)
            }.onSelected {
                $0.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
            }.onDeselected {
                $0.tintColor = UIColor.lightGray
            }.onTouchUpInside { _ in
                print("Item Tapped")
            }
    }
}

// MARK: - MessagesDataSource

extension ConversationViewController: MessagesDataSource {
    public func currentSender() -> SenderType {
        let contactDBService = ALContactDBService()
        let contact = contactDBService.loadContact(byKey: "userId", value: ALUserDefaultsHandler.getUserId()) as ALContact
        let senderContact = Contact(senderId: contact.userId, displayName: contact.displayName != nil ? contact.displayName : contact.userId)
        return senderContact
    }

    public func numberOfSections(in _: MessagesCollectionView) -> Int {
        return messageList.count
    }

    public func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }

    public func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
        }
        return nil
    }

    public func messageTopLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }

    public func messageBottomLabelAttributedText(for message: MessageType, at _: IndexPath) -> NSAttributedString? {
        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }
}

// MARK: - MessagesDisplayDelegate

extension ConversationViewController: MessagesDisplayDelegate {
    // MARK: - Text Messages

    public func textColor(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }

    public func detectorAttributes(for _: DetectorType, and _: MessageType, at _: IndexPath) -> [NSAttributedString.Key: Any] {
        return MessageLabel.defaultAttributes
    }

    public func enabledDetectors(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation]
    }

    // MARK: - All Messages

    public func backgroundColor(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? UIColor(red: 66.0 / 255, green: 173.0 / 255, blue: 247.0 / 255, alpha: 1)
            : UIColor(red: 230 / 255, green: 230 / 255, blue: 230 / 255, alpha: 1)
    }

    public func messageStyle(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }

    public func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) {
        let contactDataBase = ALContactDBService()
        let alContact = contactDataBase.loadContact(byKey: "userId", value: message.sender.senderId)

        guard let contact = alContact else {
            return
        }

        avatarView.set(avatar: Avatar(initials: contact.displayName != nil ? String(contact.displayName.first ?? "A") : String(message.sender.senderId.first ?? "A")))
    }

    // MARK: - Location Messages

    public func annotationViewForLocation(message _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> MKAnnotationView? {
        let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
        let pinImage = #imageLiteral(resourceName: "pin")
        annotationView.image = pinImage
        annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        return annotationView
    }

    public func animationBlockForLocation(message _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> ((UIImageView) -> Void)? {
        return { view in
            view.layer.transform = CATransform3DMakeScale(0, 0, 0)
            view.alpha = 0.0
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
                view.layer.transform = CATransform3DIdentity
                view.alpha = 1.0
            }, completion: nil)
        }
    }

    public func snapshotOptionsForLocation(message _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> LocationMessageSnapshotOptions {
        return LocationMessageSnapshotOptions()
    }
}

// MARK: - MessagesLayoutDelegate

extension ConversationViewController: MessagesLayoutDelegate {
    public func cellTopLabelHeight(for _: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if indexPath.section % 3 == 0 {
            return 10
        }
        return 0
    }

    public func messageTopLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        return 16
    }

    public func messageBottomLabelHeight(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        return 16
    }
}

// MARK: - MessageCellDelegate

extension ConversationViewController: MessageCellDelegate {
    public func didTapAvatar(in _: MessageCollectionViewCell) {
        print("Avatar tapped")
    }

    public func didTapMessage(in _: MessageCollectionViewCell) {
        print("Message tapped")
    }

    public func didTapCellTopLabel(in _: MessageCollectionViewCell) {
        print("Top cell label tapped")
    }

    public func didTapMessageTopLabel(in _: MessageCollectionViewCell) {
        print("Top message label tapped")
    }

    public func didTapMessageBottomLabel(in _: MessageCollectionViewCell) {
        print("Bottom label tapped")
    }
}

// MARK: - MessageLabelDelegate

extension ConversationViewController: MessageLabelDelegate {
    public func didSelectAddress(_ addressComponents: [String: String]) {
        print("Address Selected: \(addressComponents)")
    }

    public func didSelectDate(_ date: Date) {
        print("Date Selected: \(date)")
    }

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        print("Phone Number Selected: \(phoneNumber)")
    }

    public func didSelectURL(_ url: URL) {
        print("URL Selected: \(url)")
    }

    public func didSelectTransitInformation(_ transitInformation: [String: String]) {
        print("TransitInformation Selected: \(transitInformation)")
    }
}

// MARK: - MessageInputBarDelegate

extension ConversationViewController: InputBarAccessoryViewDelegate {
    @objc public func inputBar(_: InputBarAccessoryView, didPressSendButtonWith _: String) {
        processInputBar(messageInputBar)
    }

    func processInputBar(_ inputBar: InputBarAccessoryView) {
        // Here we can parse for which substrings were autocompleted
        let attributedText = inputBar.inputTextView.attributedText!
        let range = NSRange(location: 0, length: attributedText.length)
        attributedText.enumerateAttribute(.autocompleted, in: range, options: []) { _, range, _ in

            let substring = attributedText.attributedSubstring(from: range)
            let context = substring.attribute(.autocompletedContext, at: 0, effectiveRange: nil)
            print("Autocompleted: `", substring, "` with context: ", context ?? [])
        }

        let components = inputBar.inputTextView.components
        inputBar.inputTextView.text = String()
        inputBar.invalidatePlugins()
        // Send button activity animation
        inputBar.sendButton.startAnimating()
        inputBar.inputTextView.placeholder = "Sending..."
        DispatchQueue.global(qos: .default).async {
            // fake send request task
            sleep(1)
            DispatchQueue.main.async { [weak self] in
                inputBar.sendButton.stopAnimating()
                inputBar.inputTextView.placeholder = "Type a message..."
                self?.insertMessages(components)
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        }
    }

    private func insertMessages(_ data: [Any]) {
        for component in data {
            // let user = SampleData.shared.currentSender
            if let str = component as? String {
                let channelService = ALChannelService()
                if channel != nil, channelService.isChannelLeft(channel?.key) {
                    return
                }
                send(message: str, isOpenGroup: channel != nil && channel?.type != nil && channel?.type == 6)
            }
        }
    }

    open func send(message: String, isOpenGroup: Bool = false) {
        var alMessage = ALMessage()

        alMessage = ALMessage.build { alMessageBuilder in

            if self.groupId != nil, self.groupId != 0 {
                alMessageBuilder?.groupId = self.groupId

            } else {
                alMessageBuilder?.to = self.userId
            }
            alMessageBuilder?.message = message
        }

        if isOpenGroup {
            let messageClientService = ALMessageClientService()
            messageClientService.sendMessage(alMessage.dictionary(), withCompletionHandler: { _, error in
                guard error == nil else { return }
                NSLog("No errors while sending the message in open group")
                alMessage.status = NSNumber(integerLiteral: Int(SENT.rawValue))

                return
            })
        } else {
            appDelegate?.applozicClient.sendTextMessage(alMessage, withCompletion: { _, error in

                if error == nil {
                    // update the ui once message is sent
                }

            })
        }
    }

    @objc func backTapped() {
        _ = navigationController?.popViewController(animated: true)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appDelegate?.applozicClient.subscribeToConversation()
        navigationController?.navigationBar.isTranslucent = false
        if navigationController?.viewControllers.first != self {
            var backImage = UIImage(named: "icon_back", in: Bundle(for: ALChatViewController.self), compatibleWith: nil)
            backImage = backImage?.imageFlippedForRightToLeftLayoutDirection()
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(backTapped))
        }

        setTitle()

        messageInputBar.sendButton.tintColor = UIColor(red: 69 / 255, green: 193 / 255, blue: 89 / 255, alpha: 1)
        // scrollsToBottomOnKeybordBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false

        iMessage()
        messagesCollectionView.addSubview(refreshControl)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(named: "ic_keyboard"),
                            style: .plain,
                            target: self,
                            action: #selector(ConversationViewController.handleKeyboardButton)),
        ]

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "reloadData"), object: nil, queue: nil, using: { [weak self]
            notification in

            guard let weakSelf = self else { return }

            let data = notification.object as! [String: Any]

            let groupId = data["groupId"] as! NSNumber

            weakSelf.unSubscribeTypingStatus()

            if groupId != 0 {
                self?.groupId = groupId
                self?.userId = nil
            } else {
                let userId = data["userId"] as! String?
                self?.userId = userId
                self?.groupId = 0
            }

            weakSelf.messageList.removeAll()
            weakSelf.messagesCollectionView.reloadData()
            weakSelf.setTitle()
            weakSelf.loadMessages()
            weakSelf.subscribeTypingStatus()
        })
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appDelegate?.applozicClient.unsubscribeToConversation()
        unSubscribeTypingStatus()
    }

    func subscribeTypingStatus() {
        if groupId != nil, groupId != 0 {
            appDelegate?.applozicClient.subscribeToTypingStatus(forChannel: groupId)
        } else {
            appDelegate?.applozicClient.subscribeToTypingStatusForOneToOne()
        }
    }

    func unSubscribeTypingStatus() {
        if groupId != nil, groupId != 0 {
            appDelegate?.applozicClient.unSubscribeToTypingStatus(forChannel: groupId)
        } else {
            appDelegate?.applozicClient.unSubscribeToTypingStatusForOneToOne()
        }
    }

    public func addMessage(_alMessage: ALMessage) {
        convertMessageToMockMessage(_alMessage: _alMessage)
        DispatchQueue.main.async {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToBottom()
        }
    }

    public func onMessageReceived(_ alMessage: ALMessage!) {
        if alMessage.groupId != nil, alMessage.groupId != 0, groupId != nil, groupId != 0, alMessage.groupId.isEqual(to: groupId ?? 0) {
            addMessage(_alMessage: alMessage)
            markConversationAsRead()

        } else if alMessage.groupId == nil || alMessage.groupId == 0, userId != nil, userId?.isEqual(alMessage.to) ?? false {
            addMessage(_alMessage: alMessage)
            markConversationAsRead()
        } else {
            if !alMessage.isMsgHidden() {
                appDelegate?.sendLocalPush(message: alMessage)
            }
        }
    }

    public func onMessageSent(_ alMessage: ALMessage!) {
        if alMessage.groupId != nil, alMessage.groupId != 0, groupId != nil, groupId != 0, alMessage.groupId.isEqual(to: groupId ?? 0) {
            addMessage(_alMessage: alMessage)
        } else if userId != nil, userId?.isEqual(alMessage.to) ?? false {
            addMessage(_alMessage: alMessage)
        }
    }

    public func onUserDetailsUpdate(_: ALUserDetail!) {}

    public func onMessageDelivered(_: ALMessage!) {}

    public func onMessageDeleted(_: String!) {}

    public func onMessageDeliveredAndRead(_: ALMessage!, withUserId _: String!) {}

    public func onConversationDelete(_: String!, withGroupId _: NSNumber!) {}

    public func conversationRead(byCurrentUser _: String!, withGroupId _: NSNumber!) {}

    public func onUpdateTypingStatus(_ userId: String!, status: Bool) {
        if isShowTypingStatus(_userId: userId) {
            if !status {
                messageInputBar.topStackView.arrangedSubviews.first?.removeFromSuperview()
                messageInputBar.topStackViewPadding = .zero

            } else {
                messageInputBar.topStackView.arrangedSubviews.first?.removeFromSuperview()
                messageInputBar.topStackViewPadding = .zero

                let label = UILabel()

                let contactDB = ALContactDBService()

                let contact = contactDB.loadContact(byKey: "userId", value: userId) as ALContact

                label.text = String(format: "%@ is typing...", contact.displayName != nil ? contact.displayName : contact.userId)
                label.font = UIFont.boldSystemFont(ofSize: 16)
                messageInputBar.topStackView.addArrangedSubview(label)
                messageInputBar.topStackViewPadding.top = 6
                messageInputBar.topStackViewPadding.left = 12

                // The backgroundView doesn't include the topStackView. This is so things in the topStackView can have transparent backgrounds if you need it that way or another color all together
                messageInputBar.backgroundColor = messageInputBar.backgroundView.backgroundColor
            }
        }
    }

    func isShowTypingStatus(_userId: String) -> Bool {
        let channelService = ALChannelService()
        var isMemberOfChannel: Bool = false
        if groupId != nil, groupId != 0 {
            let array = channelService.getListOfAllUsers(inChannel: groupId) as NSMutableArray
            isMemberOfChannel = array.contains(_userId)
        }

        return ((userId != nil && _userId == userId && (groupId == nil || groupId == 0)) || groupId != nil && groupId != 0 && isMemberOfChannel)
    }

    public func onUpdateLastSeen(atStatus _: ALUserDetail!) {}

    public func onUserBlockedOrUnBlocked(_: String!, andBlockFlag _: Bool) {}

    public func onChannelUpdated(_: ALChannel!) {}

    public func onAllMessagesRead(_: String!) {}

    public func onMqttConnectionClosed() {}

    public func onMqttConnected() {
        subscribeTypingStatus()
    }

    public func markConversationAsRead() {
        if groupId != nil, groupId != 0 {
            appDelegate?.applozicClient.markConversationRead(forGroup: groupId) { _, _ in
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.NotificationsName.DidRecieveNewMessageNotification), object: nil)
            }
        } else {
            appDelegate?.applozicClient.markConversationRead(forOnetoOne: userId) { _, _ in
                NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.NotificationsName.DidRecieveNewMessageNotification), object: nil)
            }
        }
    }

    public func convertMessageToMockMessage(_alMessage: ALMessage) {
        switch Int32(_alMessage.contentType) {
        case ALMESSAGE_CONTENT_DEFAULT:

            var mockTextMessage = Message(text: _alMessage.message ?? "", sender: getSender(message: _alMessage), messageId: _alMessage.key, date: Date(timeIntervalSince1970: Double(_alMessage.createdAtTime.doubleValue / 1000)))
            mockTextMessage.createdAtTime = _alMessage.createdAtTime
            messageList.append(mockTextMessage)

        case ALMESSAGE_CONTENT_LOCATION:

            do {
                let objectData: Data? = _alMessage.message.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                var jsonStringDic: [AnyHashable: Any]?

                if let aData = objectData {
                    jsonStringDic = try JSONSerialization.jsonObject(with: aData, options: .mutableContainers) as? [AnyHashable: Any]
                }

                if let lat = jsonStringDic?["lat"] as? String, let aDoubleLat = Double(lat), let lon = jsonStringDic?["lon"] as? String, let aDoubleLon = Double(lon) {
                    let location = CLLocation(latitude: aDoubleLat, longitude: aDoubleLon)
                    let date = Date(timeIntervalSince1970: Double(_alMessage.createdAtTime.doubleValue / 1000))

                    var mockLocationMessage = Message(location: location, sender: getSender(message: _alMessage), messageId: _alMessage.key, date: date)
                    mockLocationMessage.createdAtTime = _alMessage.createdAtTime
                    messageList.append(mockLocationMessage)
                }
            } catch {
                print("Error while building location %@", error.localizedDescription)
            }

        default:
            break
        }
    }

    func insertMessage(_ message: Message) {
        messageList.append(message)
        // Reload last section to update header/footer labels and insert a new one
        messagesCollectionView.performBatchUpdates({
            messagesCollectionView.insertSections([messageList.count - 1])
            if messageList.count >= 1 {
                messagesCollectionView.reloadSections([messageList.count - 2])
            }
        }, completion: { [weak self] _ in
            if self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        })
    }

    func isLastSectionVisible() -> Bool {
        guard !messageList.isEmpty else { return false }

        let lastIndexPath = IndexPath(item: 0, section: messageList.count - 1)

        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }

    func getSender(message: ALMessage) -> Contact {
        let contactDB = ALContactDBService()

        var contact = ALContact()
        if message.isReceivedMessage() {
            contact = contactDB.loadContact(byKey: "userId", value: message.to)
            return Contact(senderId: message.to, displayName: contact.displayName == nil ? message.to : contact.displayName)
        } else {
            contact = contactDB.loadContact(byKey: "userId", value: ALUserDefaultsHandler.getUserId())
            return Contact(senderId: ALUserDefaultsHandler.getUserId(), displayName: contact.displayName == nil ? ALUserDefaultsHandler.getUserId() : contact.displayName)
        }
    }
}

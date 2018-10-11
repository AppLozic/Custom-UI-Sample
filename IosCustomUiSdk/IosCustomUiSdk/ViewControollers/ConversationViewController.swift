//
//  ConversationViewController.swift
//  IosCustomUiSdk
//
//  Created by Sunil on 02/10/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Foundation
import MessageKit
import UIKit
import MapKit
import Applozic


public class ConversationViewController: MessagesViewController,ApplozicUpdatesDelegate {


    let refreshControl = UIRefreshControl()

    let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate

    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)

    var applozicClient = ApplozicClient()
    var userId: String?
    var groupId: NSNumber?
    var createdAtTime: NSNumber?
    var contact : ALContact?
    var channel : ALChannel?


    var messageList: [Message] = []

    var isTyping = false

    lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()

        applozicClient = ApplozicClient.init(applicationKey: "applozic-sample-app", with: self)
        activityIndicator.center = CGPoint(x: view.bounds.size.width/2, y: view.bounds.size.height/2)
        activityIndicator.color = UIColor.gray
        view.addSubview(activityIndicator)
        self.view.bringSubview(toFront: activityIndicator)


        DispatchQueue.global(qos: .userInitiated).async {

            let req = MessageListRequest()
            if(self.groupId  != nil){
                req.channelKey =  self.groupId  // pass groupId
            }else{
                req.userId =  self.userId  // pass userId
            }
            DispatchQueue.main.async {
                self.activityIndicator.startAnimating()
                self.messagesCollectionView.isUserInteractionEnabled = false
            }

            self.applozicClient.getMessages(req) { (messageList, error) in

                guard error == nil, let newMessages = messageList as? [ALMessage] else {
                    return
                }


                for alMessage in newMessages {

                    self.convertMessageToMockMessage(_alMessage: alMessage)

                }


                self.messageList =   self.messageList.reversed()
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.messagesCollectionView.isUserInteractionEnabled = true
                    self.messagesCollectionView.reloadData()
                    self.messagesCollectionView.scrollToBottom()
                }
                self.markConversationAsRead()
            }

        }

        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self


    }

    func setTitle()  {

        if(self.groupId != nil && self.groupId != 0){
            let alChannelService = ALChannelService()
            alChannelService .getChannelInformation(byResponse: self.groupId, orClientChannelKey: nil, withCompletion: { (error, alChannel, response) in

                if(alChannel != nil){
                    self.channel = alChannel
                    self.title = alChannel?.name != nil ? alChannel?.name: "NO name"
                }

            })
        }else{
            let contactDataBase  = ALContactDBService()
            self.contact =   contactDataBase .loadContact(byKey: "userId", value: self.userId)
            self.title = contact?.displayName != nil ? contact?.displayName: contact?.userId
        }
    }

    @objc func loadMoreMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: DispatchTime.now() + 4) {

            let messagelist = MessageListRequest()

            if(self.groupId != nil && self.groupId != 0){
                messagelist.channelKey =  self.groupId// pass groupId
            }else{
                messagelist.userId =  self.userId// pass userId
            }

            messagelist.endTimeStamp = self.messageList[0].createdAtTime

            self.applozicClient.getMessages(messagelist, withCompletionHandler: { messageList, error in
                if error == nil {

                    guard error == nil, let newMessages = messageList as? [ALMessage] else {
                        return
                    }

                    var messageArray: [Message] = []


                    for alMessage in newMessages {


                        switch  Int32(alMessage.contentType)  {

                        case ALMESSAGE_CONTENT_DEFAULT:

                            let contactDB = ALContactDBService()

                            let contact =  contactDB.loadContact(byKey: "userId", value: alMessage.to) as ALContact

                            let displayName = Sender(id: alMessage.to, displayName: contact.displayName == nil ? alMessage.to: contact.displayName)

                            var mockTextMessage =   Message(text: alMessage.message, sender: displayName, messageId: alMessage.key, date:                            Date(timeIntervalSince1970: Double(alMessage.createdAtTime.doubleValue/1000)))
                            mockTextMessage.createdAtTime = alMessage.createdAtTime
                            messageArray.append(mockTextMessage)

                            break;

                        case ALMESSAGE_CONTENT_LOCATION:

                            let contactDB = ALContactDBService()

                            let contact =  contactDB.loadContact(byKey: "userId", value: alMessage.to) as ALContact

                            let sender = Sender(id: alMessage.to, displayName: contact.displayName)

                            let objectData: Data? = alMessage.message.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                            var jsonStringDic: [AnyHashable : Any]? = nil


                            if let aData = objectData {
                                jsonStringDic = try! JSONSerialization.jsonObject(with: aData, options: .mutableContainers) as? [AnyHashable : Any]
                            }

                            let latDelta: CLLocationDegrees =  Double(jsonStringDic?["lat"] as! String) ?? 0.0

                            let lonDelta: CLLocationDegrees =  Double(jsonStringDic?["lon"] as! String) ?? 0.0

                            let location =  CLLocation(latitude: latDelta, longitude: lonDelta)

                            let date =  Date(timeIntervalSince1970: Double(alMessage.createdAtTime.doubleValue/1000))

                            var mockLocationMessage =  Message(location: location, sender: sender, messageId: alMessage.key, date: date)
                            mockLocationMessage.createdAtTime = alMessage.createdAtTime

                            messageArray.append(mockLocationMessage)

                            break;
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
    }

    @objc func handleKeyboardButton() {

        messageInputBar.inputTextView.resignFirstResponder()
        let actionSheetController = UIAlertController(title: "Change Keyboard Style", message: nil, preferredStyle: .actionSheet)
        let actions = [
            UIAlertAction(title: "Slack", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    self.slack()
                })
            }),
            UIAlertAction(title: "iMessage", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    self.iMessage()
                })
            }),
            UIAlertAction(title: "Default", style: .default, handler: { _ in
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                    self.defaultStyle()
                })
            }),
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        ]
        actions.forEach { actionSheetController.addAction($0) }
        actionSheetController.view.tintColor = UIColor(red: 66.0 / 255, green: 173.0 / 255, blue: 247.0 / 255, alpha: 1)
        present(actionSheetController, animated: true, completion: nil)
    }

    // MARK: - Keyboard Style

    func slack() {
        defaultStyle()
        messageInputBar.backgroundView.backgroundColor = .white
        messageInputBar.isTranslucent = false
        messageInputBar.inputTextView.backgroundColor = .clear
        messageInputBar.inputTextView.layer.borderWidth = 0
        let items = [
            makeButton(named: "ic_camera").onTextViewDidChange { button, textView in
                button.isEnabled = textView.text.isEmpty
            },
            makeButton(named: "ic_at").onSelected {
                $0.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
            },
            makeButton(named: "ic_hashtag").onSelected {
                $0.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
            },
            .flexibleSpace,
            makeButton(named: "ic_library").onTextViewDidChange { button, textView in
                button.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
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
                    $0.backgroundColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
                    $0.layer.borderColor = UIColor.clear.cgColor
                }.onSelected {
                    // We use a transform becuase changing the size would cause the other views to relayout
                    $0.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }.onDeselected {
                    $0.transform = CGAffineTransform.identity
            }
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
        messageInputBar.isTranslucent = false
        messageInputBar.backgroundView.backgroundColor = .white
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.backgroundColor = UIColor(red: 245/255, green: 245/255, blue: 245/255, alpha: 1)
        messageInputBar.inputTextView.placeholderTextColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 36)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 36)
        messageInputBar.inputTextView.layer.borderColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1).cgColor
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
        messageInputBar.textViewPadding.right = -38
    }

    func defaultStyle() {
        let newMessageInputBar = MessageInputBar()
        newMessageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
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
                $0.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
            }.onDeselected {
                $0.tintColor = UIColor.lightGray
            }.onTouchUpInside { _ in
                print("Item Tapped")
        }
    }
}

// MARK: - MessagesDataSource

extension ConversationViewController: MessagesDataSource {

    public func currentSender() -> Sender {

        let contactDBService = ALContactDBService()
        let contact = contactDBService.loadContact(byKey: "userId", value: ALUserDefaultsHandler.getUserId()) as ALContact

        let senderContact =  Sender(id:contact.userId , displayName: contact.displayName != nil ? contact.displayName : contact.userId )

        return senderContact
    }

    public func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messageList.count
    }

    public func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }

    public func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if indexPath.section % 3 == 0 {
            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedStringKey.foregroundColor: UIColor.darkGray])
        }
        return nil
    }

    public func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let name = message.sender.displayName
        return NSAttributedString(string: name, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption1)])
    }

    public func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {

        let dateString = formatter.string(from: message.sentDate)
        return NSAttributedString(string: dateString, attributes: [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .caption2)])
    }

}

// MARK: - MessagesDisplayDelegate

extension ConversationViewController: MessagesDisplayDelegate {

    // MARK: - Text Messages

    public func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }

    public func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedStringKey: Any] {
        return MessageLabel.defaultAttributes
    }

    public func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation]
    }

    // MARK: - All Messages

    public func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? UIColor(red: 66.0 / 255, green: 173.0 / 255, blue: 247.0 / 255, alpha: 1)
            : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }

    public func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
        //        let configurationClosure = { (view: MessageContainerView) in}
        //        return .custom(configurationClosure)
    }

    public func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {


        let contactDataBase = ALContactDBService()
        let alContact = contactDataBase .loadContact(byKey:"userId", value: message.sender.id)

        guard let contact = alContact else {
            return
        }

        avatarView.set(avatar:Avatar(initials:(contact.displayName != nil ? String(contact.displayName.first ?? "A") :String(message.sender.id.first ?? "A"))) )

    }

    // MARK: - Location Messages

    public func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
        let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
        let pinImage = #imageLiteral(resourceName: "pin")
        annotationView.image = pinImage
        annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
        return annotationView
    }

    public func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
        return { view in
            view.layer.transform = CATransform3DMakeScale(0, 0, 0)
            view.alpha = 0.0
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
                view.layer.transform = CATransform3DIdentity
                view.alpha = 1.0
            }, completion: nil)
        }
    }

    public func snapshotOptionsForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LocationMessageSnapshotOptions {

        return LocationMessageSnapshotOptions()
    }
}

// MARK: - MessagesLayoutDelegate

extension ConversationViewController: MessagesLayoutDelegate {

    public  func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        if indexPath.section % 3 == 0 {
            return 10
        }
        return 0
    }

    public  func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }

    public func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 16
    }

}

// MARK: - MessageCellDelegate

extension ConversationViewController: MessageCellDelegate {

    public func didTapAvatar(in cell: MessageCollectionViewCell) {
        print("Avatar tapped")
    }

    public  func didTapMessage(in cell: MessageCollectionViewCell) {
        print("Message tapped")
    }

    public func didTapCellTopLabel(in cell: MessageCollectionViewCell) {
        print("Top cell label tapped")
    }

    public  func didTapMessageTopLabel(in cell: MessageCollectionViewCell) {
        print("Top message label tapped")
    }

    public  func didTapMessageBottomLabel(in cell: MessageCollectionViewCell) {
        print("Bottom label tapped")
    }

}

// MARK: - MessageLabelDelegate

extension ConversationViewController: MessageLabelDelegate {

    public func didSelectAddress(_ addressComponents: [String: String]) {
        print("Address Selected: \(addressComponents)")
    }

    public  func didSelectDate(_ date: Date) {
        print("Date Selected: \(date)")
    }

    public  func didSelectPhoneNumber(_ phoneNumber: String) {
        print("Phone Number Selected: \(phoneNumber)")
    }

    public func didSelectURL(_ url: URL) {
        print("URL Selected: \(url)")
    }

    public  func didSelectTransitInformation(_ transitInformation: [String: String]) {
        print("TransitInformation Selected: \(transitInformation)")
    }

}

// MARK: - MessageInputBarDelegate

extension ConversationViewController: MessageInputBarDelegate {

    public func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {

        // Each NSTextAttachment that contains an image will count as one empty character in the text: String

        for component in inputBar.inputTextView.components {

            if let image = component as? UIImage {

                let imageMessage = Message(image: image, sender: currentSender(), messageId: UUID().uuidString, date: Date())
                messageList.append(imageMessage)
                messagesCollectionView.insertSections([messageList.count - 1])

            } else if let text = component as? String {

                self.send(message: text, isOpenGroup: self.channel != nil && self.channel?.type != nil && self.channel?.type == 6)

            }
        }

        inputBar.inputTextView.text = String()
        messagesCollectionView.scrollToBottom()
    }


    open func send(message: String, isOpenGroup: Bool = false) {

        let attributedText = NSAttributedString(string: message, attributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: UIColor.white])

        var alMessage = ALMessage();

        alMessage = ALMessage.build({ alMessageBuilder in

            if(self.groupId != nil && self.groupId != 0){
                alMessageBuilder?.groupId = self.groupId

            }else{
                alMessageBuilder?.to = self.userId
            }
            alMessageBuilder?.message = message
        })


        let mockMessage = Message(attributedText: attributedText, sender: currentSender(), messageId: alMessage.key, date:  Date(timeIntervalSince1970: Double(alMessage.createdAtTime.doubleValue/1000)))

        messageList.append(mockMessage)

        messagesCollectionView.insertSections([messageList.count - 1])
        self.messagesCollectionView.reloadData()

        if isOpenGroup {
            let messageClientService = ALMessageClientService()
            messageClientService.sendMessage(alMessage.dictionary(), withCompletionHandler: {responseJson, error in
                guard error == nil else { return }
                NSLog("No errors while sending the message in open group")
                alMessage.status = NSNumber(integerLiteral: Int(SENT.rawValue))

                return
            })
        } else {
            applozicClient.sendTextMessage(alMessage, withCompletion: { (alMessage, error) in

                if(error == nil){
                    //update the ui once message is sent
                }

            })
        }

    }


    public override func viewWillAppear(_ animated: Bool) {

        //  addObserver()

        self.applozicClient.subscribeToConversation()

        if(self.groupId != nil && self.groupId != 0){
            self.applozicClient.subscribeToTypingStatus(forChannel: self.groupId)
        }else{
            self.applozicClient.subscribeToTypingStatusForOneToOne()
        }
        setTitle()

        messageInputBar.sendButton.tintColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1)
        scrollsToBottomOnKeybordBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false

        iMessage()
        messagesCollectionView.addSubview(refreshControl)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(named: "ic_keyboard"),
                            style: .plain,
                            target: self,
                            action: #selector(ConversationViewController.handleKeyboardButton)),

        ]



        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground, object: nil, queue: nil, using: { notification in

            self.appDelegate?.userId = nil

            self.appDelegate?.groupId = 0
        })

        NotificationCenter.default.addObserver(forName: .UIApplicationWillEnterForeground, object: nil, queue: nil, using: { notification in

            if(self.groupId != nil && self.groupId != 0 ){
                self.appDelegate?.groupId = self.groupId ?? 0
                self.appDelegate?.userId = nil

            }else{
                self.appDelegate?.groupId = 0
                self.appDelegate?.userId = self.userId
            }

        })



    }



    public override func viewWillDisappear(_ animated: Bool) {

        self.applozicClient.unsubscribeToConversation()

        if(self.groupId != nil && self.groupId != 0){
            self.applozicClient.unSubscribeToTypingStatus(forChannel: self.groupId)
        }else{
            self.applozicClient.unSubscribeToTypingStatusForOneToOne()
        }
    }


    public func addMessage(_alMessage:ALMessage){

        convertMessageToMockMessage(_alMessage: _alMessage)

        DispatchQueue.main.async {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToBottom()

        }

    }



    public func onMessageReceived(_ alMessage: ALMessage!) {

        if(alMessage.groupId != nil && alMessage.groupId != 0 && self.groupId != nil && self.groupId != 0 && alMessage.groupId.isEqual(to: self.groupId ?? 0) ){
            self.addMessage(_alMessage: alMessage)
            self.markConversationAsRead()

        }else if(self.userId != nil && self.userId?.isEqual(alMessage.to) ?? false ){
            self.addMessage(_alMessage: alMessage)
            self.markConversationAsRead()
        }else{
            appDelegate?.sendLocalPush(message: alMessage)
        }

    }

    public func onMessageSent(_ alMessage: ALMessage!) {

        if(alMessage.groupId != nil && alMessage.groupId != 0 && self.groupId != nil && self.groupId != 0 && alMessage.groupId.isEqual(to: self.groupId ?? 0) ){
            self.addMessage(_alMessage: alMessage)
        }else if(self.userId != nil && self.userId?.isEqual(alMessage.to) ?? false ){
            self.addMessage(_alMessage: alMessage)
        }
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

    }

    public func onUpdateTypingStatus(_ userId: String!, status: Bool) {

        if !status {

            messageInputBar.topStackView.arrangedSubviews.first?.removeFromSuperview()
            messageInputBar.topStackViewPadding = .zero

        } else {

            let label = UILabel()

            let contactDB = ALContactDBService()

            let contact =  contactDB.loadContact(byKey: "userId", value:userId) as ALContact

            label.text = contact.displayName != nil ? contact.displayName:contact.userId + " is typing..."
            label.font = UIFont.boldSystemFont(ofSize: 16)
            messageInputBar.topStackView.addArrangedSubview(label)
            messageInputBar.topStackViewPadding.top = 6
            messageInputBar.topStackViewPadding.left = 12

            // The backgroundView doesn't include the topStackView. This is so things in the topStackView can have transparent backgrounds if you need it that way or another color all together
            messageInputBar.backgroundColor = messageInputBar.backgroundView.backgroundColor

        }

    }

    public func onUpdateLastSeen(atStatus alUserDetail: ALUserDetail!) {

    }

    public func onUserBlockedOrUnBlocked(_ userId: String!, andBlockFlag flag: Bool) {

    }

    public func onChannelUpdated(_ channel: ALChannel!) {

    }

    public func onAllMessagesRead(_ userId: String!) {

    }

    public func onMqttConnectionClosed() {

    }

    public func onMqttConnected() {

    }

    public func markConversationAsRead(){

        if(self.groupId != nil && self.groupId != 0){
            applozicClient.markConversationRead(forGroup: self.groupId) { (response, error) in

            }
        }else{
            applozicClient.markConversationRead(forOnetoOne: self.userId) { (response, error) in

            }
        }

    }
    public func convertMessageToMockMessage(_alMessage:ALMessage){

        switch  Int32(_alMessage.contentType)  {

        case ALMESSAGE_CONTENT_DEFAULT:

            let contactDB = ALContactDBService()

            let contact =  contactDB.loadContact(byKey: "userId", value: _alMessage.to) as ALContact

            let displayName = Sender(id: _alMessage.to, displayName: contact.displayName == nil ? _alMessage.to: contact.displayName)

            var mockTextMessage =  Message(text: _alMessage.message, sender: displayName, messageId: _alMessage.key, date:                            Date(timeIntervalSince1970: Double(_alMessage.createdAtTime.doubleValue/1000)))
            mockTextMessage.createdAtTime = _alMessage.createdAtTime
            self.messageList.append(mockTextMessage)

            break;

        case ALMESSAGE_CONTENT_LOCATION:

            let contactDB = ALContactDBService()

            let contact =  contactDB.loadContact(byKey: "userId", value: _alMessage.to) as ALContact

            let sender = Sender(id: _alMessage.to, displayName: contact.displayName)

            let objectData: Data? = _alMessage.message.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
            var jsonStringDic: [AnyHashable : Any]? = nil


            if let aData = objectData {
                jsonStringDic = try! JSONSerialization.jsonObject(with: aData, options: .mutableContainers) as? [AnyHashable : Any]
            }

            let latDelta: CLLocationDegrees =  Double(jsonStringDic?["lat"] as! String) ?? 0.0

            let lonDelta: CLLocationDegrees =  Double(jsonStringDic?["lon"] as! String) ?? 0.0

            let location =  CLLocation(latitude: latDelta, longitude: lonDelta)

            let date =  Date(timeIntervalSince1970: Double(_alMessage.createdAtTime.doubleValue/1000))

            var mockLocationMessage =  Message(location: location, sender: sender, messageId: _alMessage.key, date: date)

            mockLocationMessage.createdAtTime = _alMessage.createdAtTime

            self.messageList.append(mockLocationMessage)

            break;
        default:
            break

        }
    }

}

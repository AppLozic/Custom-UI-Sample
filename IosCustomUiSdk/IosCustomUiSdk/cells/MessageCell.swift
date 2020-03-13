//
//  MessageCell.swift
//  IosCustomUiSdk
//
//  Created by Sunil on 28/09/18.
//  Copyright © 2018 Applozic. All rights reserved.
//

import Foundation
import UIKit
import Applozic
import Kingfisher

public class MessageCell: UITableViewCell {

    var message = ALMessage()

    private var avatarImageView: UIImageView = {
        let imv = UIImageView()
        imv.contentMode = .scaleAspectFill
        imv.clipsToBounds = true
        let layer = imv.layer
        layer.cornerRadius = 22.5
        layer.backgroundColor = UIColor.clear.cgColor
        layer.masksToBounds = true
        return imv
    }()

    private var nameLabel: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.font = UIFont.boldSystemFont(ofSize: 14.0)
        label.textColor = UIColor.black
        return label
    }()

    private var messageText: UILabel = {
        let label = UILabel()
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.black
        return label
    }()

    private var lineView: UIView = {
        let view = UIView()
        let layer = view.layer
        view.isHidden = true
        view.backgroundColor = UIColor.init(red: 200.0/255.0, green: 199.0/255.0, blue: 204.0/255.0, alpha: 0.33)
        return view
    }()

    private lazy var voipButton: UIButton = {
        let bt = UIButton(type: .custom)
        // bt.addTarget(self, action: #selector(callTapped(button:)), for: .touchUpInside)
        return bt
    }()

    // MARK: BadgeNumber
    private lazy var badgeNumberView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.red
        return view
    }()

    private lazy var badgeNumberLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = "0"
        label.textAlignment = .center
        label.textColor = UIColor.white
        label.font = UIFont.systemFont(ofSize: 9)
        return label
    }()

    private var timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.green
        label.isHidden = true
        return label
    }()

    private var onlineStatusView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = UIColor.green
        return view
    }()

    private var avatarName: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.gray
        label.layer.cornerRadius = 22.5
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.clipsToBounds = true
        label.font = UIFont.boldSystemFont(ofSize: 14.0)
        return label
    }()


    private func setupConstraints() {

        self.addViewsForAutolayout(views: [avatarImageView, nameLabel,messageText,lineView,voipButton, avatarName,badgeNumberView, timeLabel,onlineStatusView])

        avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 17.0).isActive = true
        avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15.0).isActive = true
        avatarImageView.heightAnchor.constraint(equalToConstant: 45.0).isActive = true
        avatarImageView.widthAnchor.constraint(equalToConstant: 45.0).isActive = true


        nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 2).isActive = true
        nameLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true
        nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12).isActive = true
        nameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -5).isActive = true

        timeLabel.heightAnchor.constraint(equalToConstant: 15).isActive = true
        timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5).isActive = true
        timeLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        timeLabel.topAnchor.constraint(equalTo: nameLabel.topAnchor, constant: 0).isActive  = true

        messageText.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2).isActive = true
        messageText.heightAnchor.constraint(equalToConstant: 20).isActive = true
        messageText.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12).isActive = true
        messageText.widthAnchor.constraint(equalToConstant: 300.0).isActive = true


        lineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        lineView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        lineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        lineView.heightAnchor.constraint(equalToConstant: 1).isActive = true


        // setup constraint of VOIP button
        //voipButton.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -25.0).isActive = true
        voipButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -23).isActive = true
        voipButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        voipButton.widthAnchor.constraint(equalToConstant: 24.0).isActive = true
        voipButton.heightAnchor.constraint(equalToConstant: 25.0).isActive = true

        // setup constraint of badgeNumber
        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeNumberView.addSubview(badgeNumberLabel)

        badgeNumberView.trailingAnchor.constraint(lessThanOrEqualTo: nameLabel.leadingAnchor, constant: -5)
        badgeNumberView.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 0).isActive = true
        badgeNumberView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: -12).isActive = true

        badgeNumberLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1000), for: .horizontal)
        badgeNumberLabel.topAnchor.constraint(equalTo: badgeNumberView.topAnchor, constant: 2.0).isActive = true
        badgeNumberLabel.bottomAnchor.constraint(equalTo: badgeNumberView.bottomAnchor, constant: -2.0).isActive = true
        badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeNumberView.leadingAnchor, constant: 2.0).isActive = true
        badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeNumberView.trailingAnchor, constant: -2.0).isActive = true
        badgeNumberLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 11.0).isActive = true
        badgeNumberLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 11.0).isActive = true


        onlineStatusView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        onlineStatusView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true
        onlineStatusView.widthAnchor.constraint(equalToConstant: 6).isActive = true

        avatarName.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 17.0).isActive = true
        avatarName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15.0).isActive = true
        avatarName.heightAnchor.constraint(equalToConstant: 45.0).isActive = true
        avatarName.widthAnchor.constraint(equalToConstant: 45.0).isActive = true

        // update frame
        contentView.layoutIfNeeded()

        badgeNumberView.layer.cornerRadius = badgeNumberView.frame.size.height / 2.0

    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupConstraints()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }



    func addViewsForAutolayout(views: [UIView]) {
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
    }


    func update(viewModel: ALMessage) {

        self.message = viewModel

        avatarImageView.isHidden = true
        avatarName.isHidden = true
        avatarName.backgroundColor = UIColor.gray

        var channel = ALChannel();
        var contact = ALContact ();
        if(self.message.groupId != nil ){
            let placeHolder =   ALUtilityClass .getImageFromFramworkBundle("applozic_group_icon.png")

            channel = ALChannelService.sharedInstance().getChannelByKey(self.message.groupId) as ALChannel;

            avatarImageView.isHidden = false
            if let imgStr = channel.channelImageURL,let imgURL = URL.init(string: imgStr) {

                let resource = ImageResource(downloadURL: imgURL, cacheKey: imgStr)


                avatarImageView.kf.setImage(with: resource, placeholder: placeHolder, options: nil, progressBlock: nil, completionHandler: nil)

            }else{
                avatarImageView.kf.setImage(with: nil, placeholder: placeHolder, options: nil, progressBlock: nil, completionHandler: nil)
            }

            nameLabel.text = channel.name

            if(channel.unreadCount != nil){

                let unreadMsgCount = channel.unreadCount.intValue
                let numberText: String = (unreadMsgCount < 1000 ? "\(unreadMsgCount)" : "999+")
                let isHidden = (unreadMsgCount < 1)

                badgeNumberView.isHidden = isHidden
                badgeNumberLabel.text = numberText
            }else{
                badgeNumberView.isHidden = true
            }


        }else{

            let placeHolder =   ALUtilityClass .getImageFromFramworkBundle("ic_contact_picture_holo_light.png")


            contact = ALContactDBService() .loadContact(byKey: "userId", value: message.contactIds)

            avatarImageView.isHidden = false


            if let imgStr = contact.contactImageUrl,let imgURL = URL.init(string: imgStr) {
                let resource = ImageResource(downloadURL: imgURL, cacheKey: imgStr)

                avatarImageView.kf.setImage(with: resource, placeholder: placeHolder, options: nil, progressBlock: nil, completionHandler: nil)

            }else{

                avatarImageView.kf.setImage(with: nil, placeholder: placeHolder, options: nil, progressBlock: nil, completionHandler: nil)
            }


            // get unread count of message and set badgenumber

            if(contact.unreadCount != nil){
                let unreadMsgCount = contact.unreadCount.intValue
                let numberText: String = (unreadMsgCount < 1000 ? "\(unreadMsgCount)" : "999+")
                let isHidden = (unreadMsgCount < 1)

                badgeNumberView.isHidden = isHidden
                badgeNumberLabel.text = numberText
            }else{
                badgeNumberView.isHidden = true
            }

            nameLabel.text = contact.displayName != nil ? contact.displayName : contact.userId

        }
        if(message.fileMeta != nil){
            messageText.text = "Attachement"
        }else{
            messageText.text = message.message
        }

        let date = Date(timeIntervalSince1970: Double(message.createdAtTime.doubleValue/1000))

        let isToday = ALUtilityClass.isToday(date)
        timeLabel.text =  message.getCreatedAtTime(isToday)

    }



}




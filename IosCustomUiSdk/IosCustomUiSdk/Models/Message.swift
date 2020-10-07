import Foundation
import CoreLocation
import MessageKit

private struct MessageLocationItem: LocationItem {

    var location: CLLocation
    var size: CGSize

    init(location: CLLocation) {
        self.location = location
        self.size = CGSize(width: 240, height: 240)
    }

}

private struct MessageMediaItem: MediaItem {

    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize

    init(image: UIImage) {
        self.image = image
        self.size = CGSize(width: 240, height: 240)
        self.placeholderImage = UIImage()
    }

}

internal struct Message: MessageType{
    var messageId: String
    var sender: SenderType {
        return contact
    }
    var sentDate: Date
    var kind: MessageKind
    var createdAtTime: NSNumber
    var groupId: NSNumber
    var contact: Contact

    private init(kind: MessageKind, contact: Contact, messageId: String, date: Date) {
        self.kind = kind
        self.contact = contact
        self.messageId = messageId
        self.sentDate = date
        self.createdAtTime =  0
        self.groupId =  0

    }

    init(text: String, sender: Contact, messageId: String, date: Date) {
        self.init(kind: .text(text), contact: sender, messageId: messageId, date: date)
    }

    init(attributedText: NSAttributedString, sender: Contact, messageId: String, date: Date) {
        self.init(kind: .attributedText(attributedText), contact: sender, messageId: messageId, date: date)
    }

    init(image: UIImage, sender: Contact, messageId: String, date: Date) {
        let mediaItem = MessageMediaItem(image: image)
        self.init(kind: .photo(mediaItem), contact: sender, messageId: messageId, date: date)
    }

    init(thumbnail: UIImage, sender: Contact, messageId: String, date: Date) {
        let mediaItem = MessageMediaItem(image: thumbnail)
        self.init(kind: .video(mediaItem), contact: sender, messageId: messageId, date: date)
    }

    init(location: CLLocation, sender: Contact, messageId: String, date: Date) {
        let locationItem = MessageLocationItem(location: location)
        self.init(kind: .location(locationItem), contact: sender, messageId: messageId, date: date)
    }

    init(emoji: String, sender: Contact, messageId: String, date: Date) {
        self.init(kind: .emoji(emoji), contact: sender, messageId: messageId, date: date)
    }

}

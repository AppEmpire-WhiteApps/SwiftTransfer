import Contacts
import Foundation

/// vCard export of contacts, including contact photos.
enum VCardExporter {
    /// Keys required to export complete vCards with photos.
    static var keysToFetch: [CNKeyDescriptor] {
        [
            CNContactVCardSerialization.descriptorForRequiredKeys(),
            CNContactImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
        ]
    }

    /// Serializes contacts to vCard 3.0. `CNContactVCardSerialization` omits photos,
    /// so a base64 `PHOTO` property is added to cards that have image data.
    static func data(for contacts: [CNContact]) throws -> Data {
        guard !contacts.isEmpty else { return Data() }
        let raw = try CNContactVCardSerialization.data(with: contacts)
        let photos = contacts.map(imageData(of:))
        guard photos.contains(where: { $0 != nil }), let text = String(data: raw, encoding: .utf8) else {
            return raw
        }

        let marker = "END:VCARD"
        var cards = text.components(separatedBy: marker)
        // The last component is the trailing newline after the final END:VCARD.
        guard cards.count == contacts.count + 1 else { return raw }
        for index in contacts.indices {
            guard let photo = photos[index], !cards[index].contains("\nPHOTO") else { continue }
            cards[index] += photoLine(for: photo) + "\r\n"
        }
        return Data(cards.joined(separator: marker).utf8)
    }

    /// `PHOTO;ENCODING=b;TYPE=JPEG:<base64>` folded to 75 octets.
    static func photoLine(for imageData: Data) -> String {
        let type = imageData.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "PNG" : "JPEG"
        let line = "PHOTO;ENCODING=b;TYPE=\(type):" + imageData.base64EncodedString()
        return ICSWriter.fold(line)
    }

    private static func imageData(of contact: CNContact) -> Data? {
        guard contact.isKeyAvailable(CNContactImageDataKey) else { return nil }
        return contact.imageData
    }
}

import Foundation

// MARK: - Vendor Mapper (FBVendor → ZBContact)

struct VendorMapper {

    static func map(_ vendor: FBVendor) -> ZBContact {
        // Build contact name with fallback logic
        let contactName: String
        if let name = vendor.vendorName, !name.isEmpty {
            contactName = name
        } else {
            contactName = "Vendor \(vendor.vendorId)"
        }

        // Build contact person
        var contactPerson = ZBContactPerson()
        contactPerson.firstName = vendor.primaryContactFirstName
        contactPerson.lastName = vendor.primaryContactLastName
        contactPerson.email = vendor.primaryContactEmail
        contactPerson.phone = vendor.phone
        contactPerson.isPrimaryContact = true

        // Build billing address
        var billingAddress = ZBAddress()
        let street = [vendor.street, vendor.street2]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        billingAddress.address = street.isEmpty ? nil : street
        billingAddress.city = vendor.city
        billingAddress.state = vendor.province
        billingAddress.zip = vendor.postalCode
        billingAddress.country = vendor.country

        // Build the contact
        var contact = ZBContact(
            contactName: contactName,
            contactType: "vendor"
        )
        contact.companyName = vendor.vendorName
        contact.contactPersons = [contactPerson]
        contact.billingAddress = billingAddress.isEmpty ? nil : billingAddress
        contact.currencyCode = vendor.currencyCode
        contact.notes = vendor.note
        contact.website = vendor.website
        contact.taxId = vendor.taxId

        return contact
    }

    /// Create a minimal vendor contact from just a name (for on-the-fly creation)
    static func mapFromName(_ name: String) -> ZBContact {
        var contact = ZBContact(
            contactName: name,
            contactType: "vendor"
        )
        contact.companyName = name
        return contact
    }
}

import Foundation

// MARK: - Customer Mapper (FBClient → ZBContact)

struct CustomerMapper {

    static func map(_ client: FBClient) -> ZBContact {
        // Build contact name with fallback logic
        let contactName: String
        if let org = client.organization, !org.isEmpty {
            contactName = org
        } else {
            let first = client.fname ?? ""
            let last = client.lname ?? ""
            let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
            if !fullName.isEmpty {
                contactName = fullName
            } else {
                contactName = "Unknown Client \(client.id)"
            }
        }

        // Build contact person
        var contactPerson = ZBContactPerson()
        contactPerson.firstName = client.fname
        contactPerson.lastName = client.lname
        contactPerson.email = client.email
        contactPerson.phone = client.busPhone ?? client.homePhone
        contactPerson.mobile = client.mobPhone
        contactPerson.isPrimaryContact = true

        // Build billing address
        var billingAddress = ZBAddress()
        let billingStreet = [client.pStreet, client.pStreet2]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        billingAddress.address = billingStreet.isEmpty ? nil : billingStreet
        billingAddress.city = client.pCity
        billingAddress.state = client.pProvince
        billingAddress.zip = client.pCode
        billingAddress.country = client.pCountry

        // Build shipping address
        var shippingAddress = ZBAddress()
        let shippingStreet = [client.sStreet, client.sStreet2]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        shippingAddress.address = shippingStreet.isEmpty ? nil : shippingStreet
        shippingAddress.city = client.sCity
        shippingAddress.state = client.sProvince
        shippingAddress.zip = client.sCode
        shippingAddress.country = client.sCountry

        // Build the contact
        var contact = ZBContact(
            contactName: contactName,
            contactType: "customer"
        )
        contact.companyName = client.organization
        contact.contactPersons = [contactPerson]
        contact.billingAddress = billingAddress.isEmpty ? nil : billingAddress
        contact.shippingAddress = shippingAddress.isEmpty ? nil : shippingAddress
        contact.currencyCode = client.currencyCode
        contact.notes = client.note
        contact.taxId = client.vatNumber

        return contact
    }
}

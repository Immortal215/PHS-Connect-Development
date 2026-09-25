import Foundation

func parseClubEmails(_ input: String) -> (valid: [String], invalidCount: Int) {
    let entries = input.split(omittingEmptySubsequences: true) {
        $0 == "," || $0 == ";" || $0 == "/" || $0.isNewline
    }
    var valid: [String] = []
    var invalidCount = 0

    for entry in entries {
        let value = String(entry).trimmingCharacters(in: .whitespacesAndNewlines)
        let address: String
        if let start = value.firstIndex(of: "<"),
            let end = value[start...].firstIndex(of: ">"), start < end
        {
            address = String(value[value.index(after: start)..<end])
        } else {
            address = value
        }
        let email = address.replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            invalidCount += 1
            continue
        }
        let local = parts[0]
        let domain = parts[1]
        let allowedLocalPunctuation = ".!#$%&'*+=?^_`{|}~-"
        let validLocal = !local.isEmpty
            && !local.hasPrefix(".") && !local.hasSuffix(".")
            && !local.contains("..")
            && local.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber
                    || allowedLocalPunctuation.contains($0))
            }
        let validDomain = domain == "gmail.com" || domain == "d214.org"
            || (domain.hasSuffix(".d214.org") && !domain.hasPrefix(".")
                && !domain.contains(".."))
        if validLocal && validDomain {
            valid.append(email)
        } else {
            invalidCount += 1
        }
    }
    return (valid, invalidCount)
}

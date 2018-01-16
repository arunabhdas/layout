//  Copyright © 2017 Schibsted. All rights reserved.

import UIKit

// Convert any object to a string
func stringify(_ value: Any) throws -> String {
    switch try unwrap(value) {
    case let bool as Bool:
        return bool ? "true" : "false"
    case let number as NSNumber:
        if let int = Int64(exactly: number) {
            return "\(int)"
        }
        if let uint = UInt64(exactly: number) {
            return "\(uint)"
        }
        return "\(number)"
    case let value as NSAttributedString:
        return value.string
    case let value:
        return "\(value)"
    }
}

// Flatten an array of dictionaries
func merge(_ dictionaries: [[String: Any]]) -> [String: Any] {
    var result = [String: Any]()
    for dict in dictionaries {
        for (key, value) in dict {
            result[key] = value
        }
    }
    return result
}

private let classPrefix = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "")
    .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)

// Get a class by name, adding project prefix if needed
func classFromString(_ name: String) -> AnyClass? {
    return NSClassFromString(name) ?? NSClassFromString("\(classPrefix).\(name)")
}

// Get the name of a class, without project prefix
func nameOfClass(_ name: AnyClass) -> String {
    let name = NSStringFromClass(name)
    let prefix = "\(classPrefix)."
    if name.hasPrefix(prefix) {
        return String(name[prefix.endIndex...])
    }
    return name
}

// Get a protocol by name
func protocolFromString(_ name: String) -> Protocol? {
    return NSProtocolFromString(name) ?? NSProtocolFromString("\(classPrefix).\(name)")
}

// Internal API for converting a path to a full URL
func urlFromString(_ path: String, relativeTo baseURL: URL? = nil) -> URL {
    if path.hasPrefix("~") {
        let path = path.removingPercentEncoding ?? path
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if let url = URL(string: path, relativeTo: baseURL), url.scheme != nil {
        return url
    }

    // Check if url has a scheme
    if baseURL != nil || path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path, relativeTo: baseURL) {
            return url
        }
    }

    // Assume local path
    if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path.removingPercentEncoding ?? path)
    } else {
        return Bundle.main.resourceURL!.appendingPathComponent(path)
    }
}

// MARK: Optionals

// Unwraps a potentially optional value or throws if nil
func unwrap(_ value: Any) throws -> Any {
    switch value {
    case let optional as _Optional:
        guard let value = optional.value else {
            fallthrough
        }
        return try unwrap(value)
    case is NSNull:
        throw AnyExpression.Error.message("Unexpected nil value")
    default:
        return value
    }
}

// Unwraps a potentially optional value or returns nil
func optionalValue(of value: Any) -> Any? {
    guard let optional = value as? _Optional else {
        return value is NSNull ? nil : value
    }
    return optional.value
}

// Test if a value is nil
func isNil(_ value: Any) -> Bool {
    if let optional = value as? _Optional {
        guard let value = optional.value else {
            return true
        }
        return isNil(value)
    }
    return value is NSNull
}

// Used to test if a value is Optional
private protocol _Optional {
    var value: Any? { get }
}

extension Optional: _Optional {
    fileprivate var value: Any? { return self }
}

extension ImplicitlyUnwrappedOptional: _Optional {
    fileprivate var value: Any? { return self }
}

// MARK: Approximate equality

private let precision: CGFloat = 0.001

extension CGPoint {
    func isNearlyEqual(to other: CGPoint?) -> Bool {
        guard let other = other else { return false }
        return abs(x - other.x) <= precision && abs(y - other.y) <= precision
    }
}

extension CGSize {
    func isNearlyEqual(to other: CGSize?) -> Bool {
        guard let other = other else { return false }
        return abs(width - other.width) <= precision && abs(height - other.height) <= precision
    }
}

extension UIEdgeInsets {
    func isNearlyEqual(to other: UIEdgeInsets?) -> Bool {
        guard let other = other else { return false }
        return
            abs(left - other.left) <= precision &&
            abs(right - other.right) <= precision &&
            abs(top - other.top) <= precision &&
            abs(bottom - other.bottom) <= precision
    }
}

// MARK: Backwards compatibility

struct IntOptionSet: OptionSet {
    let rawValue: Int
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

struct UIntOptionSet: OptionSet {
    let rawValue: UInt
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

#if swift(>=4)
#else

    extension NSAttributedString {
        struct DocumentType {
            static let html = NSHTMLTextDocumentType
        }

        struct DocumentReadingOptionKey {
            static let documentType = NSDocumentTypeDocumentAttribute
            static let characterEncoding = NSCharacterEncodingDocumentAttribute
        }
    }

    extension NSAttributedStringKey {
        static let foregroundColor = NSForegroundColorAttributeName
        static let font = NSFontAttributeName
        static let paragraphStyle = NSParagraphStyleAttributeName
    }

    extension UIFont {
        typealias Weight = UIFontWeight
    }

    extension UIFont.Weight {
        static let ultraLight = UIFontWeightUltraLight
        static let thin = UIFontWeightThin
        static let light = UIFontWeightLight
        static let regular = UIFontWeightRegular
        static let medium = UIFontWeightMedium
        static let semibold = UIFontWeightSemibold
        static let bold = UIFontWeightBold
        static let heavy = UIFontWeightHeavy
        static let black = UIFontWeightBlack
    }

    extension UIFontDescriptor {
        struct AttributeName {
            static let traits = UIFontDescriptorTraitsAttribute
        }

        typealias TraitKey = String
    }

    extension UIFontDescriptor.TraitKey {
        static let weight = UIFontWeightTrait
    }

    extension UILayoutPriority {
        var rawValue: Float { return self }
        init(rawValue: Float) { self = rawValue }

        static let required = UILayoutPriorityRequired
        static let defaultHigh = UILayoutPriorityDefaultHigh
        static let defaultLow = UILayoutPriorityDefaultLow
        static let fittingSizeLevel = UILayoutPriorityFittingSizeLevel
    }

    extension Int64 {
        init?(exactly number: NSNumber) {
            self.init(exactly: Double(number))
        }
    }

    extension Double {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension CGFloat {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Float {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Int {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension UInt {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

    extension Bool {
        init(truncating number: NSNumber) {
            self.init(number)
        }
    }

#endif

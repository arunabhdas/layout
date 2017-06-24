//
//  UIView+Layout.swift
//  Layout
//
//  Created by Nick Lockwood on 26/04/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

extension UIView {

    /// The view controller that owns the view - used to access layout guides
    var viewController: UIViewController? {
        var controller: UIViewController? = nil
        var responder: UIResponder? = self.next
        while responder != nil {
            if let responder = responder as? UIViewController {
                controller = responder
                break
            }
            responder = responder?.next
        }
        return controller
    }

    /// Expression names and types
    @objc open class var expressionTypes: [String: RuntimeType] {
        var types = allPropertyTypes()
        // TODO: support more properties
        types["alpha"] = RuntimeType(CGFloat.self)
        types["backgroundColor"] = RuntimeType(UIColor.self)
        types["clipsToBounds"] = RuntimeType(Bool.self)
        types["contentMode"] = RuntimeType(UIViewContentMode.self, [
            "scaleToFill": .scaleToFill,
            "scaleAspectFit": .scaleAspectFit,
            "scaleAspectFill": .scaleAspectFill,
            "redraw": .redraw,
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "left": .left,
            "right": .right,
            "topLeft": .topLeft,
            "topRight": .topRight,
            "bottomLeft": .bottomLeft,
            "bottomRight": .bottomRight,
        ])
        types["isHidden"] = RuntimeType(Bool.self)
        types["layoutMargins"] = RuntimeType(UIEdgeInsets.self)
        types["layoutMargins.top"] = RuntimeType(CGFloat.self)
        types["layoutMargins.left"] = RuntimeType(CGFloat.self)
        types["layoutMargins.bottom"] = RuntimeType(CGFloat.self)
        types["layoutMargins.right"] = RuntimeType(CGFloat.self)
        types["preservesSuperviewLayoutMargins"] = RuntimeType(Bool.self)
        types["tintColor"] = RuntimeType(UIColor.self)
        // TODO: better approach to layer properties?
        for (name, type) in (layerClass as! NSObject.Type).allPropertyTypes() {
            types["layer.\(name)"] = type
        }
        types["layer.contents"] = RuntimeType(CGImage.self)
        // Explicitly disabled properties
        for name in [
            "center",
            "center.x",
            "center.y",
            "layer.anchorPoint",
            "layer.bounds",
            "layer.bounds.x",
            "layer.bounds.y",
            "layer.bounds.width",
            "layer.bounds.height",
            "layer.bounds.origin",
            "layer.bounds.size",
            "layer.frame",
            "layer.frame.x",
            "layer.frame.y",
            "layer.frame.width",
            "layer.frame.height",
            "layer.frame.origin",
            "layer.frame.size",
            "layer.position",
            "layer.position.x",
            "layer.position.y",
            "layer.sublayers",
        ] {
            assert(types[name] != nil)
            types.removeValue(forKey: name)
        }
        return types
    }

    private static var propertiesKey = 0
    class var cachedExpressionTypes: [String: RuntimeType] {
        if let types = objc_getAssociatedObject(self, &propertiesKey) as? [String: RuntimeType] {
            return types
        }
        let types = expressionTypes
        objc_setAssociatedObject(self, &propertiesKey, types, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return types
    }

    /// Called to construct the view
    @objc open class func create(with node: LayoutNode) throws -> UIView {
        return self.init()
    }

    // Set expression value
    @objc open func setValue(_ value: Any, forExpression name: String) throws {
        var value = value
        if let type = type(of: self).cachedExpressionTypes[name]?.type, case let .enum(_, _, adaptor) = type {
            value = adaptor(value) // TODO: something nicer than this
        }
        try _setValue(value, forKeyPath: name)
    }

    /// Get symbol value
    @objc open func value(forSymbol name: String) -> Any? {
        return _value(forKeyPath: name)
    }

    /// Called immediately after a child node is added
    @objc open func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        insertSubview(node.view, at: index)
    }

    /// Called immediately before a child node is removed
    @objc open func willRemoveChildNode(_ node: LayoutNode, at index: Int) {
        for controller in node.viewControllers {
            controller.removeFromParentViewController()
        }
        node.view.removeFromSuperview()
    }

    /// Called immediately after layout has been performed
    @objc open func didUpdateLayout(for node: LayoutNode) {}
}

extension UIScrollView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["indicatorStyle"] = RuntimeType(UIScrollViewIndicatorStyle.self, [
            "default": .default,
            "black": .black,
            "white": .white,
        ])
        types["indexDisplayMode"] = RuntimeType(UIScrollViewIndexDisplayMode.self, [
            "automatic": .automatic,
            "alwaysHidden": .alwaysHidden,
        ])
        types["keyboardDismissMode"] = RuntimeType(UIScrollViewKeyboardDismissMode.self, [
            "none": .none,
            "onDrag": .onDrag,
            "interactive": .interactive,
        ])
        return types
    }

    open override func didUpdateLayout(for node: LayoutNode) {
        guard type(of: self) == UIScrollView.self else {
            return // Skip this behavior for subclasses like UITableView
        }
        // Update contentSize
        contentSize = node.contentSize
        // Prevents contentOffset glitch when rotating from portrait to landscape
        if isPagingEnabled {
            let offset = CGPoint(
                x: round(contentOffset.x / frame.size.width) * frame.size.width - contentInset.left,
                y: round(contentOffset.y / frame.size.height) * frame.size.height - contentInset.top
            )
            guard !offset.x.isNaN && !offset.y.isNaN else { return }
            contentOffset = offset
        }
    }
}

private let controlEvents: [String: UIControlEvents] = [
    "touchDown": .touchDown,
    "touchDownRepeat": .touchDownRepeat,
    "touchDragInside": .touchDragInside,
    "touchDragOutside": .touchDragOutside,
    "touchDragEnter": .touchDragEnter,
    "touchDragExit": .touchDragExit,
    "touchUpInside": .touchUpInside,
    "touchUpOutside": .touchUpOutside,
    "touchCancel": .touchCancel,
    "valueChanged": .valueChanged,
    "primaryActionTriggered": .primaryActionTriggered,
    "editingDidBegin": .editingDidBegin,
    "editingChanged": .editingChanged,
    "editingDidEnd": .editingDidEnd,
    "editingDidEndOnExit": .editingDidEndOnExit,
    "allTouchEvents": .allTouchEvents,
    "allEditingEvents": .allEditingEvents,
    "allEvents": .allEvents,
]

private var layoutActionsKey: UInt8 = 0
extension UIControl {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for name in controlEvents.keys {
            types[name] = RuntimeType(String.self)
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        if let action = value as? String, let event = controlEvents[name] {
            var actions = objc_getAssociatedObject(self, &layoutActionsKey) as? [String: String] ?? [String: String]()
            if let oldAction = actions[name] {
                if oldAction == action {
                    return
                }
                removeTarget(nil, action: Selector(action), for: event)
            }
            addTarget(nil, action: Selector(action), for: event)
            actions[name] = action
            objc_setAssociatedObject(self, &layoutActionsKey, actions, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }
        try super.setValue(value, forExpression: name)
    }
}

extension UIButton {

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["type"] = RuntimeType(UIButtonType.self, [
            "custom": .custom,
            "system": .system,
            "detailDisclosure": .detailDisclosure,
            "infoLight": .infoLight,
            "infoDark": .infoDark,
            "contactAdd": .contactAdd,
        ])
        types["buttonType"] = types["type"]
        // Title
        types["title"] = RuntimeType(String.self)
        types["highlightedTitle"] = RuntimeType(String.self)
        types["disabledTitle"] = RuntimeType(String.self)
        types["selectedTitle"] = RuntimeType(String.self)
        types["focusedTitle"] = RuntimeType(String.self)
        // Title color
        types["titleColor"] = RuntimeType(UIColor.self)
        types["highlightedTitleColor"] = RuntimeType(UIColor.self)
        types["disabledTitleColor"] = RuntimeType(UIColor.self)
        types["selectedTitleColor"] = RuntimeType(UIColor.self)
        types["focusedTitleColor"] = RuntimeType(UIColor.self)
        // Title shadow color
        types["titleShadowColor"] = RuntimeType(UIColor.self)
        types["highlightedTitleShadowColor"] = RuntimeType(UIColor.self)
        types["disabledTitleShadowColor"] = RuntimeType(UIColor.self)
        types["selectedTitleShadowColor"] = RuntimeType(UIColor.self)
        types["focusedTitleShadowColor"] = RuntimeType(UIColor.self)
        // Image
        types["image"] = RuntimeType(UIImage.self)
        types["highlightedImage"] = RuntimeType(UIImage.self)
        types["disabledImage"] = RuntimeType(UIImage.self)
        types["selectedImage"] = RuntimeType(UIImage.self)
        types["focusedImage"] = RuntimeType(UIImage.self)
        // Backgrounf image
        types["backgroundImage"] = RuntimeType(UIImage.self)
        types["highlightedBackgroundImage"] = RuntimeType(UIImage.self)
        types["disabledBackgroundImage"] = RuntimeType(UIImage.self)
        types["selectedBackgroundImage"] = RuntimeType(UIImage.self)
        types["focusedBackgroundImage"] = RuntimeType(UIImage.self)
        // Attributed title
        types["attributedTitle"] = RuntimeType(NSAttributedString.self)
        types["highlightedAttributedTitle"] = RuntimeType(NSAttributedString.self)
        types["disabledAttributedTitle"] = RuntimeType(NSAttributedString.self)
        types["selectedAttributedTitle"] = RuntimeType(NSAttributedString.self)
        types["focusedAttributedTitle"] = RuntimeType(NSAttributedString.self)
        // Setters used for embedded html
        types["text"] = RuntimeType(String.self)
        types["attributedText"] = RuntimeType(NSAttributedString.self)
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "type", "buttonType": setValue((value as! UIButtonType).rawValue, forKey: "buttonType")
        // Title
        case "title": setTitle(value as? String, for: .normal)
        case "highlightedTitle": setTitle(value as? String, for: .highlighted)
        case "disabledTitle": setTitle(value as? String, for: .disabled)
        case "selectedTitle": setTitle(value as? String, for: .selected)
        case "focusedTitle": setTitle(value as? String, for: .focused)
        // Title color
        case "titleColor": setTitleColor(value as? UIColor, for: .normal)
        case "highlightedTitleColor": setTitleColor(value as? UIColor, for: .highlighted)
        case "disabledTitleColor": setTitleColor(value as? UIColor, for: .disabled)
        case "selectedTitleColor": setTitleColor(value as? UIColor, for: .selected)
        case "focusedTitleColor": setTitleColor(value as? UIColor, for: .focused)
        // Title shadow color
        case "titleShadowColor": setTitleShadowColor(value as? UIColor, for: .normal)
        case "highlightedTitleShadowColor": setTitleShadowColor(value as? UIColor, for: .highlighted)
        case "disabledTitleShadowColor": setTitleShadowColor(value as? UIColor, for: .disabled)
        case "selectedTitleShadowColor": setTitleShadowColor(value as? UIColor, for: .selected)
        case "focusedTitleShadowColor": setTitleShadowColor(value as? UIColor, for: .focused)
        // Image
        case "image": setImage(value as? UIImage, for: .normal)
        case "highlightedImage": setImage(value as? UIImage, for: .highlighted)
        case "disabledImage": setImage(value as? UIImage, for: .disabled)
        case "selectedImage": setImage(value as? UIImage, for: .selected)
        case "focusedImage": setImage(value as? UIImage, for: .focused)
        // Background image
        case "backgroundImage": setBackgroundImage(value as? UIImage, for: .normal)
        case "highlightedBackgroundImage": setBackgroundImage(value as? UIImage, for: .highlighted)
        case "disabledBackgroundImage": setBackgroundImage(value as? UIImage, for: .disabled)
        case "selectedBackgroundImage": setBackgroundImage(value as? UIImage, for: .selected)
        case "focusedBackgroundImage": setBackgroundImage(value as? UIImage, for: .focused)
        // Attributed title
        case "attributedTitle": setAttributedTitle(value as? NSAttributedString, for: .normal)
        case "highlightedAttributedTitle": setAttributedTitle(value as? NSAttributedString, for: .highlighted)
        case "disabledAttributedTitle": setAttributedTitle(value as? NSAttributedString, for: .disabled)
        case "selectedAttributedTitle": setAttributedTitle(value as? NSAttributedString, for: .selected)
        case "focusedAttributedTitle": setAttributedTitle(value as? NSAttributedString, for: .focused)
        // Setter used for embedded html
        case "text": setTitle(value as? String, for: .normal)
        case "attributedText": setAttributedTitle(value as? NSAttributedString, for: .normal)
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

private let textInputTraits: [String: RuntimeType] = {
    var keyboardTypes: [String: UIKeyboardType] = [
        "default": .default,
        "asciiCapable": .asciiCapable,
        "numbersAndPunctuation": .numbersAndPunctuation,
        "URL": .URL,
        "url": .URL,
        "numberPad": .numberPad,
        "phonePad": .phonePad,
        "namePhonePad": .namePhonePad,
        "emailAddress": .emailAddress,
        "decimalPad": .decimalPad,
        "twitter": .twitter,
        "webSearch": .webSearch,
    ]
    if #available(iOS 10.0, *) {
        keyboardTypes["asciiCapableNumberPad"] = .asciiCapableNumberPad
    }
    return [
        "autocapitalizationType": RuntimeType(UITextAutocapitalizationType.self, [
            "none": .none,
            "words": .words,
            "sentences": .sentences,
            "allCharacters": .allCharacters,
        ]),
        "autocorrectionType": RuntimeType(UITextAutocorrectionType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ]),
        "spellCheckingType": RuntimeType(UITextSpellCheckingType.self, [
            "default": .default,
            "no": .no,
            "yes": .yes,
        ]),
        "keyboardType": RuntimeType(UIKeyboardType.self, keyboardTypes),
        "keyboardAppearance": RuntimeType(UIKeyboardAppearance.self, [
            "default": .default,
            "dark": .dark,
            "light": .light,
        ]),
        "returnKeyType": RuntimeType(UIReturnKeyType.self, [
            "default": .default,
            "go": .go,
            "google": .google,
            "join": .join,
            "next": .next,
            "route": .route,
            "search": .search,
            "send": .send,
            "yahoo": .yahoo,
            "done": .done,
            "emergencyCall": .emergencyCall,
            "continue": .continue,
        ]),
        "enablesReturnKeyAutomatically": RuntimeType(Bool.self),
        "isSecureTextEntry": RuntimeType(Bool.self),
    ]
}()

private let textTraits = [
    "textAlignment": RuntimeType(NSTextAlignment.self, [
        "left": .left,
        "right": .right,
        "center": .center,
    ])
]

extension UILabel {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textTraits {
            types[name] = type
        }
        types["baselineAdjustment"] = RuntimeType(UIBaselineAdjustment.self, [
            "alignBaselines": .alignBaselines,
            "alignCenters": .alignCenters,
            "none": .none,
        ])
        return types
    }
}

private let textFieldViewMode = RuntimeType(UITextFieldViewMode.self, [
    "never": .never,
    "whileEditing": .whileEditing,
    "unlessEditing": .unlessEditing,
    "always": .always,
])

extension UITextField {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in textTraits {
            types[name] = type
        }
        types["borderStyle"] = RuntimeType(UITextBorderStyle.self, [
            "none": .none,
            "line": .line,
            "bezel": .bezel,
            "roundedRect": .roundedRect,
        ])
        types["clearButtonMode"] = textFieldViewMode
        types["leftViewMode"] = textFieldViewMode
        types["rightViewMode"] = textFieldViewMode
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "autocapitalizationType": autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType": autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType": spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType": keyboardType = value as! UIKeyboardType
        case "keyboardAppearance": keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType": returnKeyType = value as! UIReturnKeyType
        case "enablesReturnKeyAutomatically": enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry": isSecureTextEntry = value as! Bool
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

extension UITextView {
    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        for (name, type) in textInputTraits {
            types[name] = type
        }
        for (name, type) in textTraits {
            types[name] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "autocapitalizationType": autocapitalizationType = value as! UITextAutocapitalizationType
        case "autocorrectionType": autocorrectionType = value as! UITextAutocorrectionType
        case "spellCheckingType": spellCheckingType = value as! UITextSpellCheckingType
        case "keyboardType": keyboardType = value as! UIKeyboardType
        case "keyboardAppearance": keyboardAppearance = value as! UIKeyboardAppearance
        case "returnKeyType": returnKeyType = value as! UIReturnKeyType
        case "enablesReturnKeyAutomatically": enablesReturnKeyAutomatically = value as! Bool
        case "isSecureTextEntry": isSecureTextEntry = value as! Bool
        default:
            try super.setValue(value, forExpression: name)
        }
    }
}

private let tableViewStyle = RuntimeType(UITableViewStyle.self, [
    "plain": .plain,
    "grouped": .grouped,
])

private var tableViewNodeDataKey = 0
private var tableViewNodesKey = 0

extension UITableView {
    open override class func create(with node: LayoutNode) throws -> UIView {
        var style = UITableViewStyle.plain
        if let expression = node.expressions["style"] {
            let styleExpression = LayoutExpression(expression: expression, type: tableViewStyle, for: node)
            style = try styleExpression.evaluate() as! UITableViewStyle
        }
        return UITableView(frame: .zero, style: style)
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["style"] = tableViewStyle
        types["separatorStyle"] = RuntimeType(UITableViewCellSeparatorStyle.self, [
            "none": .none,
            "singleLine": .singleLine,
            "singleLineEtched": .singleLineEtched,
        ])
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "style":
            break // Ignore this - we set it during creation
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        guard let _ = node.view as? UITableViewCell else {
            super.didInsertChildNode(node, at: index)
            return
        }
        preconditionFailure("Inserting UITableViewCells directly in xml is not supported")
    }

    private class LayoutData {
        let name: String
        let bundle: Bundle
        let relativeTo: String
        let state: Any
        let constants: [String: Any]
        init(name: String, bundle: Bundle, relativeTo: String, state: Any, constants: [String: Any]) {
            self.name = name
            self.bundle = bundle
            self.relativeTo = relativeTo
            self.state = state
            self.constants = constants
        }
    }

    private func merge(_ dictionaries: [[String: Any]]) -> [String: Any] {
        var result = [String: Any]()
        for dict in dictionaries {
            for (key, value) in dict {
                result[key] = value
            }
        }
        return result
    }

    public func registerLayout(
        named: String,
        bundle: Bundle = Bundle.main,
        relativeTo: String = #file,
        state: Any = (),
        constants: [String: Any]...,
        forCellReuseIdentifier identifier: String
    ) {
        var xmlData = objc_getAssociatedObject(self, &tableViewNodeDataKey) as? NSMutableDictionary
        if  xmlData == nil {
            xmlData = [:]
            objc_setAssociatedObject(self, &tableViewNodeDataKey, xmlData, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        xmlData?[identifier] = LayoutData(
            name: named,
            bundle: bundle,
            relativeTo: relativeTo,
            state: state,
            constants: merge(constants)
        )
    }

    public func dequeueReusableLayoutNode(withIdentifier identifier: String, for indexPath: IndexPath) -> LayoutNode {
        if let cell = dequeueReusableCell(withIdentifier: identifier) {
            guard let layoutNode = cell.layoutNode else {
                preconditionFailure("\(type(of: cell)) is not a Layout-managed view")
            }
            return layoutNode
        }
        guard let xmlData = objc_getAssociatedObject(self, &tableViewNodeDataKey) as? NSMutableDictionary,
            let layoutData = xmlData[identifier] as? LayoutData else {
                preconditionFailure("No Layout XML has been registered for `identifier`")
        }
        var nodes = objc_getAssociatedObject(self, &tableViewNodesKey) as? NSMutableArray
        if nodes == nil {
            nodes = []
            objc_setAssociatedObject(self, &tableViewNodesKey, nodes, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        let node = try! LayoutLoader().loadLayout(
            named: layoutData.name,
            bundle: layoutData.bundle,
            relativeTo: layoutData.relativeTo,
            state: layoutData.state,
            constants: layoutData.constants
        )
        nodes?.add(node)
        node.view.setValue(identifier, forKey: "reuseIdentifier")
        return node
    }
}

private let tableViewCellStyle = RuntimeType(UITableViewCellStyle.self, [
    "default": .default,
    "value1": .value1,
    "value2": .value2,
    "subtitle": .subtitle,
])

private var tableViewCellNodeKey = 0

extension UITableViewCell {
    private class Box {
        weak var node: LayoutNode?
        init(_ node: LayoutNode) {
            self.node = node
        }
    }

    public var layoutNode: LayoutNode? {
        return (objc_getAssociatedObject(self, &tableViewCellNodeKey) as? Box)?.node
    }

    open override class func create(with node: LayoutNode) throws -> UIView {
        var style = UITableViewCellStyle.default
        if let expression = node.expressions["style"] {
            let styleExpression = LayoutExpression(expression: expression, type: tableViewCellStyle, for: node)
            style = try styleExpression.evaluate() as! UITableViewCellStyle
        }
        var reuseIdentifier: String?
        if let expression = node.expressions["reuseIdentifier"] {
            let idExpression = LayoutExpression(expression: expression, type: RuntimeType(String.self), for: node)
            reuseIdentifier = try idExpression.evaluate() as? String
        }
        let cell = UITableViewCell(style: style, reuseIdentifier: reuseIdentifier)
        objc_setAssociatedObject(cell, &tableViewCellNodeKey, Box(node), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return cell
    }

    open override class var expressionTypes: [String: RuntimeType] {
        var types = super.expressionTypes
        types["style"] = tableViewCellStyle
        types["reuseIdentifier"] = RuntimeType(String.self)
        types["selectionStyle"] = RuntimeType(UITableViewCellSelectionStyle.self, [
            "none": .none,
            "blue": .blue,
            "gray": .gray,
            "default": .default,
        ])
        types["focusStyle"] = RuntimeType(UITableViewCellFocusStyle.self, [
            "default": .default,
            "custom": .custom,
        ])
        types["accessoryType"] = RuntimeType(UITableViewCellAccessoryType.self, [
            "none": .none,
            "disclosureIndicator": .disclosureIndicator,
            "detailDisclosureButton": .detailDisclosureButton,
            "checkmark": .checkmark,
            "detailButton": .detailButton,
        ])
        types["editingAccessoryType"] = types["accessoryType"]
        for (key, type) in UIImageView.expressionTypes {
            types["imageView.\(key)"] = type
        }
        for (key, type) in UILabel.expressionTypes {
            types["textLabel.\(key)"] = type
            types["detailTextLabel.\(key)"] = type
        }
        return types
    }

    open override func setValue(_ value: Any, forExpression name: String) throws {
        switch name {
        case "style", "reuseIdentifier":
            break // Ignore this - we set it during creation
        default:
            try super.setValue(value, forExpression: name)
        }
    }

    open override func didInsertChildNode(_ node: LayoutNode, at index: Int) {
        if let viewController = self.viewController {
            for controller in node.viewControllers {
                viewController.addChildViewController(controller)
            }
        }
        // Insert child views into `contentView` instead of directly
        contentView.insertSubview(node.view, at: index)
    }
}

//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation

struct Layout {
    var `class`: AnyClass
    var outlet: String?
    var constants: [String: Any]
    var expressions: [String: String]
    var children: [Layout]
    var xmlPath: String?
    var relativePath: String?
}

private func urlFromString(_ path: String) -> URL? {
    if let url = URL(string: path), url.scheme != nil {
        return url
    }

    // Check for scheme
    if path.contains(":") {
        let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        if let url = URL(string: path) {
            return url
        }
    }

    // Assume local path
    let path = path.removingPercentEncoding ?? path
    if path.hasPrefix("~") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    } else if (path as NSString).isAbsolutePath {
        return URL(fileURLWithPath: path)
    } else {
        return Bundle.main.resourceURL?.appendingPathComponent(path)
    }
}

extension LayoutNode {
    /// Create a new LayoutNode instance from a Layout template
    convenience init(layout: Layout, outlet: String? = nil, state: Any = ()) throws {
        try self.init(
            class: layout.class,
            outlet: outlet ?? layout.outlet,
            state: state,
            constants: layout.constants,
            expressions: layout.expressions,
            children: layout.children.map {
                try LayoutNode(layout: $0)
            }
        )
        guard let xmlPath = layout.xmlPath, let xmlURL = urlFromString(xmlPath) else {
            return
        }
        var deferredError: Error?
        LayoutLoader().loadLayout(
            withContentsOfURL: xmlURL, relativeTo: layout.relativePath
        ) { [weak self] node, error in
            if let node = node {
                do {
                    try self?.update(with: node)
                } catch {
                    deferredError = error
                }
            } else if let error = error {
                deferredError = error
            }
        }
        // TODO: what about errors thrown by deferred load?
        if let error = deferredError {
            throw error
        }
    }
}
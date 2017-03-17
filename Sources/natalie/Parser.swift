//
//  Parser.swift
//  Natalie
//
//  Created by Marcin Krzyzanowski on 07/08/16.
//  Copyright © 2016 Marcin Krzyzanowski. All rights reserved.
//

import Foundation


struct Parser {

    struct Header: CustomStringConvertible {
        var description: String {
            var output = String()
            output += "//\n"
            output += "// Autogenerated by Natalie - Storyboard Generator\n"
            output += "// by Marcin Krzyzanowski http://krzyzanowskim.com\n"
            output += "// Fork by Sergej Jaskiewicz https://github.com/broadwaylamb/Natalie\n"
            output += "//\n"
            output += "// DO NOT EDIT!\n"
            output += "//\n\n"
            return output
        }
    }

    let storyboards: [StoryboardFile]
    let header = Header()

    init(storyboards: [StoryboardFile]) {
        self.storyboards = storyboards
    }

    func process(os: OS) -> String {
        var output = String()

        output += header.description
        output += "import \(os.framework)\n"
        for module in storyboards.lazy.flatMap({ $0.storyboard.customModules }) {
            output += "import \(module)\n"
        }
        output += "\n"
        output += "// MARK: - Storyboards\n"

        output += "\n"
        output += "extension \(os.storyboardType) {\n"
        for (signatureType, returnType) in os.storyboardInstantiationInfo {
            output += "    func instantiateViewController<T: \(returnType)>(ofType type: T.Type) -> T? where T: IdentifiableProtocol {\n"
            output += "        let instance = type.init()\n"
            output += "        if let identifier = instance.storyboardIdentifier {\n"
            output += "            return self.instantiate\(signatureType)(withIdentifier: identifier) as? T\n"
            output += "        }\n"
            output += "        return nil\n"
            output += "    }\n"
            output += "\n"
        }
        output += "}\n"

        output += "\n"
        output += "protocol Storyboard {\n"
        output += "    static var storyboard: \(os.storyboardType) { get }\n"
        output += "    static var identifier: String { get }\n"
        output += "}\n"
        output += "\n"

        output += "struct Storyboards {\n"
        for file in storyboards {
            output += file.storyboard.processStoryboard(storyboardName: file.storyboardName, os: os)
        }
        output += "}\n"
        output += "\n"

        output += "// MARK: - ReusableKind\n"
        output += "enum ReusableKind: String, CustomStringConvertible {\n"
        output += "    case tableViewCell = \"tableViewCell\"\n"
        output += "    case collectionViewCell = \"collectionViewCell\"\n"
        output += "    case collectionReusableView = \"collectionReusableView\"\n"
        output += "\n"
        output += "    var description: String { return self.rawValue }\n"
        output += "}\n"
        output += "\n"

        output += "// MARK: - SegueKind\n"
        output += "enum SegueKind: String, CustomStringConvertible {    \n"
        output += "    case Relationship = \"relationship\" \n"
        output += "    case Show = \"show\"                 \n"
        output += "    case Presentation = \"presentation\" \n"
        output += "    case Embed = \"embed\"               \n"
        output += "    case Unwind = \"unwind\"             \n"
        output += "    case Push = \"push\"                 \n"
        output += "    case Modal = \"modal\"               \n"
        output += "    case Popover = \"popover\"           \n"
        output += "    case Replace = \"replace\"           \n"
        output += "    case Custom = \"custom\"             \n"
        output += "\n"
        output += "    var description: String { return self.rawValue } \n"
        output += "}\n"
        output += "\n"
        output += "// MARK: - IdentifiableProtocol\n"
        output += "\n"
        output += "public protocol IdentifiableProtocol: Equatable {\n"
        output += "    var storyboardIdentifier: String? { get }\n"
        output += "}\n"
        output += "\n"
        output += "// MARK: - SegueProtocol\n"
        output += "\n"
        output += "public protocol SegueProtocol {\n"
        output += "    var identifier: String? { get }\n"
        output += "}\n"
        output += "\n"

        output += "public func ==<T: SegueProtocol, U: SegueProtocol>(lhs: T, rhs: U) -> Bool {\n"
        output += "    return lhs.identifier == rhs.identifier\n"
        output += "}\n"
        output += "\n"
        output += "public func ==<T: SegueProtocol>(lhs: T, rhs: String) -> Bool {\n"
        output += "    return lhs.identifier == rhs\n"
        output += "}\n"
        output += "\n"
        output += "public func ==<T: SegueProtocol>(lhs: String, rhs: T) -> Bool {\n"
        output += "    return lhs == rhs.identifier\n"
        output += "}\n"
        output += "\n"

        output += "// MARK: - ReusableViewProtocol\n"
        output += "public protocol ReusableViewProtocol {\n"
        output += "    associatedtype ViewType: \(os.viewType)\n"
        output += "    static var reuseIdentifier: String { get }"
        output += "}\n"
        output += "\n"

        output += "extension \(os.storyboardSegueType): SegueProtocol {\n"
        output += "}\n"
        output += "\n"

        if os == OS.iOS {
            output += "// MARK: - UICollectionView\n"
            output += "\n"
            output += "extension UICollectionView {\n"
            output += "\n"
            output += "    func dequeue<T: ReusableViewProtocol>(reusable: T.Type, for: IndexPath) -> T.ViewType where T.ViewType : UICollectionViewCell {\n"
            output += "        return dequeueReusableCell(withReuseIdentifier: reusable.reuseIdentifier, for: `for`)  as! T.ViewType\n"
            output += "    }\n"
            output += "\n"
            output += "    func register<T: ReusableViewProtocol>(reusable: T.Type) where T.ViewType : UICollectionViewCell {\n"
            output += "        register(reusable.ViewType.self, forCellWithReuseIdentifier: reusable.reuseIdentifier)\n"
            output += "    }\n"
            output += "\n"
            output += "    func dequeueReusableSupplementaryViewOfKind<T: ReusableViewProtocol>(elementKind: String, withReusable reusable: T.Type, for: IndexPath) -> T.ViewType  where T.ViewType : UICollectionReusableView {\n"
            output += "        return dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: reusable.reuseIdentifier, for: `for`) as! T.ViewType\n"
            output += "    }\n"
            output += "\n"
            output += "    func register<T: ReusableViewProtocol>(reusable: T.Type, forSupplementaryViewOfKind elementKind: String) where T.ViewType : UICollectionReusableView {\n"
            output += "        register(reusable.ViewType.self, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: reusable.reuseIdentifier)\n"
            output += "    }\n"
            output += "}\n"

            output += "// MARK: - UITableView\n"
            output += "\n"
            output += "extension UITableView {\n"
            output += "\n"
            output += "    func dequeue<T: ReusableViewProtocol>(reusable: T.Type, for: IndexPath) -> T.ViewType where T.ViewType : UITableViewCell {\n"
            output += "        return dequeueReusableCell(withIdentifier: reusable.reuseIdentifier, for: `for`) as! T.ViewType\n"
            output += "    }\n"
            output += "\n"
            output += "    func register<T: ReusableViewProtocol>(reusable: T.Type) where T.ViewType : UITableViewCell {\n"
            output += "        register(reusable.ViewType.self, forCellReuseIdentifier: reusable.reuseIdentifier)\n"
            output += "    }\n"
            output += "\n"
            output += "    func dequeueReusableHeaderFooter<T: ReusableViewProtocol>(_ reusable: T.Type) -> T.ViewType where T.ViewType : UITableViewHeaderFooterView {\n"
            output += "        return dequeueReusableHeaderFooterView(withIdentifier: reusable.reuseIdentifier) as! T.ViewType\n"
            output += "    }\n"
            output += "\n"
            output += "    func registerReusableHeaderFooter<T: ReusableViewProtocol>(_ reusable: T.Type) where T.ViewType : UITableViewHeaderFooterView {\n"
            output += "         register(reusable.ViewType.self, forHeaderFooterViewReuseIdentifier: reusable.reuseIdentifier)\n"
            output += "    }\n"
            output += "}\n"
            output += "\n"
        }

        for file in storyboards {
            output += file.storyboard.processViewControllers()
        }

        return output
    }
}

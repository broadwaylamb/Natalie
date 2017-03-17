//
//  Storyboard.swift
//  Natalie
//
//  Created by Marcin Krzyzanowski on 07/08/16.
//  Copyright © 2016 Marcin Krzyzanowski. All rights reserved.
//

class Storyboard: XMLObject {

    let version: String
    lazy var os:OS = {
        guard let targetRuntime = self.xml["document"].element?.attributes["targetRuntime"] else {
            return OS.iOS
        }

        return OS(targetRuntime: targetRuntime)
    }()

    lazy var initialViewControllerClass: String? = {
        if let initialViewControllerId = self.xml["document"].element?.attributes["initialViewController"],
            let xmlVC = self.searchById(id: initialViewControllerId)
        {
            let vc = ViewController(xml: xmlVC)
            if let customClassName = vc.customClass {
                return customClassName
            }

            if let controllerType = self.os.controllerTypeForElementName(name: vc.name) {
                return controllerType
            }
        }
        return nil
    }()

    lazy var scenes: [Scene] = {
        guard let scenes = self.searchAll(root: self.xml, attributeKey: "sceneID") else {
            return []
        }

        return scenes.map { Scene(xml: $0) }
    }()

    lazy var customModules: [String] = self.scenes.filter{ $0.customModule != nil && $0.customModuleProvider == nil  }.map{ $0.customModule! }

    override init(xml: XMLIndexer) {
        self.version = xml["document"].element!.attributes["version"]!
        super.init(xml: xml)
    }

    func processStoryboard(storyboardName: String, os: OS) -> String {
        var output = String()

        output += "\n"
        output += "    struct \(storyboardName): Storyboard {\n"
        output += "\n"
        output += "        static let identifier = \"\(storyboardName)\"\n"
        output += "\n"
        output += "        static var storyboard: \(os.storyboardType) {\n"
        output += "            return \(os.storyboardType)(name: self.identifier, bundle: nil)\n"
        output += "        }\n"
        if let initialViewControllerClass = self.initialViewControllerClass {
            let cast = (initialViewControllerClass == os.storyboardControllerReturnType ? (os == OS.iOS ? "!" : "") : " as! \(initialViewControllerClass)")
            output += "\n"
            output += "        static func instantiateInitial\(os.storyboardControllerSignatureType)() -> \(initialViewControllerClass) {\n"
            output += "            return self.storyboard.instantiateInitial\(os.storyboardControllerSignatureType)()\(cast)\n"
            output += "        }\n"
        }
        for (signatureType, returnType) in os.storyboardInstantiationInfo {
            let cast = (returnType == os.storyboardControllerReturnType ? "" : " as! \(returnType)")
            output += "\n"
            output += "        static func instantiate\(signatureType)(withIdentifier: String) -> \(returnType) {\n"
            output += "            return self.storyboard.instantiate\(signatureType)(withIdentifier: identifier)\(cast)\n"
            output += "        }\n"

            output += "\n"
            output += "        static func instantiateViewController<T: \(returnType)>(ofType type: T.Type) -> T? where T: IdentifiableProtocol {\n"
            output += "            return self.storyboard.instantiateViewController(ofType: type)\n"
            output += "        }\n"
        }
        for scene in self.scenes {
            if let viewController = scene.viewController, let storyboardIdentifier = viewController.storyboardIdentifier {
                guard let controllerClass = viewController.customClass ?? os.controllerTypeForElementName(name: viewController.name) else {
                    continue
                }

                let cast = (controllerClass == os.storyboardControllerReturnType ? "" : " as! \(controllerClass)")
                output += "\n"
                output += "        static func instantiate\(SwiftRepresentationForString(string: storyboardIdentifier, capitalizeFirstLetter: true))() -> \(controllerClass) {\n"
                output += "            return self.storyboard.instantiate\(os.storyboardControllerSignatureType)(withIdentifier: \"\(storyboardIdentifier)\")\(cast)\n"
                output += "        }\n"
            }
        }
        output += "    }\n"

        return output
    }

    func processViewControllers() -> String {
        var output = String()

        for scene in self.scenes {
            if let viewController = scene.viewController {
                if let customClass = viewController.customClass {
                    output += "\n"
                    output += "// MARK: - \(customClass)\n"

                    if let storyboardIdentifier = viewController.storyboardIdentifier {
                        output += "\n"
                        output += "extension \(customClass) : IdentifiableProtocol {\n"
                        if viewController.customModule != nil {
                            output += "    var storyboardIdentifier: String? { return \"\(storyboardIdentifier)\" }\n"
                        } else {
                            output += "    public var storyboardIdentifier: String? { return \"\(storyboardIdentifier)\" }\n"
                        }
                        output += "    static var storyboardIdentifier: String? { return \"\(storyboardIdentifier)\" }\n"
                        output += "}\n"
                        output += "\n"
                    }

                    if let segues = scene.segues?.filter({ return $0.identifier != nil }), segues.count > 0 {
                        output += "extension \(customClass) { \n"
                        output += "\n"
                        output += "    enum SegueIdentifier : String {\n"

                        for segue in segues {
                            if let identifier = segue.identifier {
                                output += "        case \(SwiftRepresentationForString(string: identifier)) = \"\(identifier)\"\n"
                            }
                        }

                        output += "    }\n\n"

                        output += "    func performSegue(withIdentifier identifier: SegueIdentifier, sender: Any? = nil) {\n"
                        output += "        performSegue(withIdentifier: identifier.rawValue, sender: sender)\n"
                        output += "    }\n\n"

                        output += "    enum Segue : SegueProtocol {\n"

                        func getGestinationClass(forDestinationElement element: XMLElement) -> String? {

                            if let customClass = element.attributes["customClass"] { return customClass }

                            if let customClass = element.attributes["referencedIdentifier"] { return customClass }

                            if let storyboardName = element.attributes["storyboardName"],
                                let storyboardFile = storyboardFiles.first(where: { $0.storyboardName == storyboardName }),
                                let customClass = storyboardFile.storyboard.initialViewControllerClass {

                                return customClass
                            }
                            
                            return os.controllerTypeForElementName(name: element.name)
                        }

                        for segue in segues {
                            if let identifier = segue.identifier, let destination = segue.destination,
                                let destinationElement = searchById(id: destination)?.element
                            {

                                output += "        case \(SwiftRepresentationForString(string: identifier))"

                                if let destinationClass = getGestinationClass(forDestinationElement: destinationElement) {
                                    output += "(destination: \(destinationClass))\n"
                                }
                            }
                        }

                        output += "\n"

                        var identifierProperty = ""
                        for segue in segues {

                            if let identifier = segue.identifier {

                                identifierProperty += "            case .\(SwiftRepresentationForString(string: identifier)):\n"
                                identifierProperty += "                return \"\(identifier)\"\n"
                            }
                        }

                        output += "        var identifier: String? {\n"

                        if !identifierProperty.isEmpty {

                            output += "            switch self {\n"

                            output += identifierProperty

                            output += "            }\n"
                        } else {
                            output += "            return nil"
                        }

                        output += "        }\n\n"

                        output += "        init?(from segue: \(os.storyboardSegueType)) {\n\n"
                        output += "            switch segue.identifier {\n"

                        for segue in segues {

                            if let identifier = segue.identifier, let destination = segue.destination,
                               let destinationElement = searchById(id: destination)?.element,
                               let destinationClass = getGestinationClass(forDestinationElement: destinationElement) {

                                output += "            case .some(\"\(identifier)\"):\n"
                                output += "                self = .\(SwiftRepresentationForString(string: identifier))(destination: segue.destination as! \(destinationClass))\n"
                            }
                        }

                        output += "            default:\n"
                        output += "                return nil\n"
                        output += "            }\n"
                        output += "        }\n"

                        output += "    }\n"
                        output += "}\n"
                    }

                    if let reusables = viewController.reusables?.filter({ return $0.reuseIdentifier != nil }), reusables.count > 0 {

                        output += "extension \(customClass) { \n"
                        output += "\n"
                        output += "    struct Reusable {\n"
                        for reusable in reusables {
                            if let identifier = reusable.reuseIdentifier {

                                let defaultClass: String
                                switch reusable.kind {
                                case "tableViewCell":
                                    defaultClass = "UITableViewCell"
                                case "collectionReusableView":
                                    defaultClass = "UICollectionReusableView"
                                default:
                                    defaultClass = "UICollectionViewCell"
                                }

                                output += "        struct \(SwiftRepresentationForString(string: identifier, capitalizeFirstLetter: true, doNotShadow: reusable.customClass)) : ReusableViewProtocol {\n"
                                output += "            typealias ViewType = \(reusable.customClass ?? defaultClass)\n"
                                output += "            static let reuseIdentifier = \"\(identifier)\"\n"
                                output += "        }\n"
                            }
                        }
                        output += "    }\n"
                        output += "}\n"
                    }
                }
            }
        }
        return output
    }
}


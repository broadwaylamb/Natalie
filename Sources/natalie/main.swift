//
//  main.swift
//  Natalie
//
//  Created by Marcin Krzyzanowski on 07/08/16.
//  Copyright © 2016 Marcin Krzyzanowski. All rights reserved.
//

import Foundation

if CommandLine.arguments.count == 1 {
    print("Invalid usage. Missing path to storyboard.")
    exit(1)
}

var filePaths: [String] = []
let storyboardSuffix = ".storyboard"

for argument in CommandLine.arguments.dropFirst() {

    if argument.hasSuffix(storyboardSuffix) {
        filePaths.append(argument)
    } else if let s = findStoryboards(rootPath: argument, suffix: storyboardSuffix) {
        filePaths.append(contentsOf: s)
    }
}


let storyboardFiles = filePaths.flatMap { try? StoryboardFile(filePath: $0) }

for os in OS.allValues {
    let storyboardsForOS = storyboardFiles.filter({ $0.storyboard.os == os })
    if !storyboardsForOS.isEmpty {
        var output = String()

        if storyboardsForOS.count != storyboardFiles.count {
            output += "#if os(\(os.rawValue))\n"
        }

        output += Parser(storyboards: storyboardsForOS).process(os: os)

        if storyboardsForOS.count != storyboardFiles.count {
            output += "#endif\n"
        }

        print(output)
    }
}

exit(0)


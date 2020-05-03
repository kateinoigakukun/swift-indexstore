protocol OptionSetDisplayable: OptionSet {
    static var debugDescriptors: [(option: Element, name: String)] { get }
}

extension OptionSetDisplayable {
    func dumpOptions() -> [String] {
        var options: [String] = []
        for (option, optionName) in Self.debugDescriptors {
            guard contains(option) else { continue }
            options.append(optionName)
        }
        return options
    }
}

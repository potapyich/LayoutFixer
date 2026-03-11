import Carbon
import os

/// Reads and switches macOS keyboard input sources via the TIS API.
class InputSourceManager {
    static let shared = InputSourceManager()
    private let logger = Logger(subsystem: "com.potapyich.LayoutFixer", category: "InputSource")
    private var qwertyCache: [String: Bool] = [:]
    private init() {}

    // MARK: - Layout support tier

    func support(for layoutID: String) -> LayoutSupport {
        if LayoutMapping.isQwertyBase(layoutID) || LayoutMapping.hasExplicitMapping(for: layoutID) {
            return .full
        }
        if let cached = qwertyCache[layoutID] { return cached ? .qwerty : .none }
        return probeAndCache(layoutID)
    }

    // MARK: - Available layouts

    /// Returns one layout per primary language from all enabled/selectable sources.
    ///
    /// Why not `kTISPropertyInputSourceIsSelected`:
    ///   On macOS it returns only the single currently-active layout, not the full
    ///   user list.
    /// Why not `kTISPropertyInputSourceIsEnabled` alone:
    ///   Returns every variant Apple ships (~20+ US layouts).
    /// Solution: use isEnabled, then deduplicate by primary language code,
    ///   preferring the currently-active variant when duplicates exist.
    func availableLayouts() -> [LayoutInfo] {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false)
            .takeRetainedValue() as! [TISInputSource]

        struct Entry {
            let source: TISInputSource
            let id: String; let name: String; let langs: [String]; let isActive: Bool
        }

        var seen: [String: Entry] = [:]

        for source in sources {
            guard
                let idPtr   = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
            else { continue }

            let id   = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue()   as String
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String

            var langs: [String] = []
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
                langs = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as! [String]
            }

            var isActive = false
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelected) {
                isActive = (Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue)
            }

            let key = langs.first ?? id
            if seen[key] == nil || isActive {
                seen[key] = Entry(source: source, id: id, name: name, langs: langs, isActive: isActive)
            }
        }

        return seen.values.compactMap { entry in
            if qwertyCache[entry.id] == nil,
               !LayoutMapping.isQwertyBase(entry.id),
               !LayoutMapping.hasExplicitMapping(for: entry.id) {
                qwertyCache[entry.id] = isQwertyBased(entry.source)
            }
            return LayoutInfo(id: entry.id, name: entry.name,
                              flag: LayoutInfo.flag(for: entry.langs, sourceID: entry.id))
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Current layout

    func currentLayoutID() -> String? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    // MARK: - Switch

    func switchTo(layoutID: String) {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceID as String: layoutID,
        ]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false)
            .takeRetainedValue() as! [TISInputSource]
        guard let source = sources.first else {
            logger.debug("No source found for ID: \(layoutID)"); return
        }
        TISSelectInputSource(source)
        logger.debug("Switched to: \(layoutID)")
    }

    // MARK: - Defaults

    func suggestedDefaults() -> [LayoutInfo] {
        let all = availableLayouts()
        var result: [LayoutInfo] = []
        if let en = all.first(where: { LayoutMapping.isQwertyBase($0.id) }) { result.append(en) }
        if let other = all.first(where: { !result.contains($0) })           { result.append(other) }
        return result.isEmpty ? Array(all.prefix(2)) : result
    }

    // MARK: - UCKeyTranslate QWERTY detection

    private func isQwertyBased(_ source: TISInputSource) -> Bool {
        guard let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return false
        }
        let cfData = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue() as Data
        return cfData.withUnsafeBytes { rawPtr -> Bool in
            guard let layoutPtr = rawPtr.baseAddress?
                .assumingMemoryBound(to: UCKeyboardLayout.self) else { return false }
            var char = UniChar(0); var deadState = UInt32(0); var actualLen = 0
            let status = UCKeyTranslate(
                layoutPtr, 12, UInt16(kUCKeyActionDown), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadState, 1, &actualLen, &char
            )
            return status == noErr && actualLen == 1 && char == 0x71
        }
    }

    private func probeAndCache(_ layoutID: String) -> LayoutSupport {
        let filter: [String: Any] = [kTISPropertyInputSourceID as String: layoutID]
        let sources = TISCreateInputSourceList(filter as CFDictionary, false)
            .takeRetainedValue() as! [TISInputSource]
        guard let source = sources.first else { qwertyCache[layoutID] = false; return .none }
        let result = isQwertyBased(source)
        qwertyCache[layoutID] = result
        return result ? .qwerty : .none
    }
}

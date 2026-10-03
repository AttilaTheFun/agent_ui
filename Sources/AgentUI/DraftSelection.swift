import SwiftUI

/// Where the caret is in the composer's field, on the platforms whose
/// SwiftUI says where; nothing elsewhere.
#if canImport(AppKit) || canImport(UIKit)
typealias DraftSelection = TextSelection
#else
struct DraftSelection: Equatable {}
#endif

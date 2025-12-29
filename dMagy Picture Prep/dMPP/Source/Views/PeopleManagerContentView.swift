import SwiftUI

/// Thin wrapper used by window routing / Settings tab hosting.
/// The real People Manager UI is in `DMPPPeopleManagerView`.
struct PeopleManagerContentView: View {
    var body: some View {
        DMPPPeopleManagerView()
    }
}

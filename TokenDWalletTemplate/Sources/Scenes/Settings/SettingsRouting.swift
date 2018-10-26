import Foundation

extension Settings {
    struct Routing {
        let showProgress: () -> Void
        let hideProgress: () -> Void
        let showErrorMessage: (_ errorMessage: String) -> Void
        let onCellSelected: (_ cellIdentifier: CellIdentifier) -> Void
    }
}

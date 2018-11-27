import Foundation
import TokenDSDK
import TokenDWallet

extension UpdatePassword {
    
    class RecoverWalletWorker: BaseSubmitWorker {
        
        // MARK: - Overridden
        
        override func getExpectedFields() -> [Model.Field] {
            return [
                Model.Field(type: .email, value: nil),
                Model.Field(type: .seed, value: nil),
                Model.Field(type: .newPassword, value: nil),
                Model.Field(type: .confirmPassword, value: nil)
            ]
        }
        
        // MARK: - Private
        
        private func getEmail(fields: [Model.Field]) -> String? {
            return self.fieldValueForType(fields: fields, fieldType: .email)
        }
        
        private func getSeed(fields: [Model.Field]) -> String? {
            return self.fieldValueForType(fields: fields, fieldType: .seed)
        }
        
        private func getNewPassword(fields: [Model.Field]) -> String? {
            return self.fieldValueForType(fields: fields, fieldType: .newPassword)
        }
        
        private func getConfirmPassword(fields: [Model.Field]) -> String? {
            return self.fieldValueForType(fields: fields, fieldType: .confirmPassword)
        }
        
        private func submitRecovery(
            email: String,
            seed: String,
            newPassword: String,
            networkInfo: NetworkInfoModel,
            stopLoading: @escaping () -> Void,
            completion: @escaping (_ result: UpdatePasswordSubmitWorkerProtocol.Result) -> Void) {
            
            _ = self.keyserverApi.recoverWallet(
                email: email,
                recoverySeedBase32Check: seed,
                newPassword: newPassword,
                networkInfo: networkInfo,
                completion: { (result) in
                    stopLoading()
                    
                    switch result {
                        
                    case .failed(let error):
                        completion(.failed(.submitError(error)))
                        
                    case .succeeded:
                        completion(.succeeded)
                    }
            })
        }
    }
}

extension UpdatePassword.RecoverWalletWorker: UpdatePassword.SubmitPasswordHandler {
    func submitFields(
        _ fields: [UpdatePassword.Model.Field],
        startLoading: @escaping () -> Void,
        stopLoading: @escaping () -> Void,
        completion: @escaping (_ result: UpdatePasswordSubmitWorkerProtocol.Result) -> Void
        ) {
        
        guard let email = self.getEmail(fields: fields), email.count > 0 else {
            completion(.failed(.emptyField(.email)))
            return
        }
        
        guard let seed = self.getSeed(fields: fields), seed.count > 0 else {
            completion(.failed(.emptyField(.seed)))
            return
        }
        
        guard let newPassword = self.getNewPassword(fields: fields), newPassword.count > 0 else {
            completion(.failed(.emptyField(.newPassword)))
            return
        }
        
        guard let confirmPassword = self.getConfirmPassword(fields: fields), confirmPassword.count > 0 else {
            completion(.failed(.emptyField(.confirmPassword)))
            return
        }
        
        guard newPassword == confirmPassword else {
            completion(.failed(.passwordsDontMatch))
            return
        }
        
        startLoading()
        self.networkInfoFetcher.fetchNetworkInfo({ [weak self] (result) in
            switch result {
                
            case .failed(let error):
                stopLoading()
                completion(.failed(.networkInfoFetchFailed(error)))
                
            case .succeeded(let info):
                self?.submitRecovery(
                    email: email,
                    seed: seed,
                    newPassword: newPassword,
                    networkInfo: info,
                    stopLoading: stopLoading,
                    completion: completion
                )
            }
        })
    }
}
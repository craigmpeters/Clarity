//
//  ClarityStore.swift
//  Clarity
//
//  Created by Craig Peters on 03/05/2026.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class Store {
    var hasBoughtPremium: Bool = UserDefaults.hasBoughtPremium {
        didSet { UserDefaults.hasBoughtPremium = hasBoughtPremium }
    }

    init() {
        Task(priority: .background) {
            for await verificationResult in Transaction.unfinished {
                await handle(updatedTransaction: verificationResult)
            }

            for await verificationResult in Transaction.currentEntitlements {
                await handle(updatedTransaction: verificationResult)
            }
        }

        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                await handle(updatedTransaction: verificationResult)
            }
        }
    }

    func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }

        if transaction.revocationDate != nil {
            guard let productID = ProductID(rawValue: transaction.productID) else {
                print("Unexpected product: \(transaction.productID).")
                return
            }

            switch productID {
            case .premium:
                hasBoughtPremium = false
            default:
                // TODO: Tips
                return
            }

            await transaction.finish()
            return
        } else {
            guard let productID = ProductID(rawValue: transaction.productID) else {
                print("Unexpected product: \(transaction.productID).")
                return
            }

            switch productID {
            case .premium:
                hasBoughtPremium = true
            default:
                // TODO: Tips
                return
            }

            await transaction.finish()
            return
        }
    }
}

enum ProductID: String {
    case premium
    case tip
}

extension ProductID {
    static let all = [ProductID.premium.rawValue]
}

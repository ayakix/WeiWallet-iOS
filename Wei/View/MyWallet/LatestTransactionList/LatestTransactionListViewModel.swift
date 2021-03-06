//
//  LatestTransactionListViewModel.swift
//  Wei
//
//  Created by Ryosuke Fukuda on 2018/04/14.
//  Copyright © 2018 yz. All rights reserved.
//

import Foundation
import EthereumKit
import RxSwift
import RxCocoa

final class LatestTransactionListViewModel: InjectableViewModel {
    
    typealias Dependency = (
        WalletManagerProtocol,
        GethRepositoryProtocol,
        UpdaterProtocol
    )
    
    private let walletManager: WalletManagerProtocol
    private let gethRepository: GethRepositoryProtocol
    private let updater: UpdaterProtocol
    
    init(dependency: Dependency) {
        (walletManager, gethRepository, updater) = dependency
    }
    
    struct Input {
        let viewWillAppear: Driver<Void>
        let refreshControlDidRefresh: Driver<Void>
    }
    
    struct Output {
        let latestTransactions: Driver<[TransactionHistory]>
        let isFetching: Driver<Bool>
        let error: Driver<Error>
    }
    
    func build(input: Input) -> Output {
        let geth = gethRepository
        let myAddress = walletManager.address()
        
        // Represents initial get transaction action. emits only when view will appear and updater.refreshTransactions.
        // the reason why initial and refresh actions are separated is to prevent a refresh control to be animated
        let getTransactionAction = Driver.merge(input.viewWillAppear, updater.refreshTransactions.asDriver(onErrorDriveWith: .empty()))
            .flatMap { _ -> Driver<Action<Transactions>> in
                let source = geth.getTransactions(address: myAddress)
                return Action.makeDriver(source)
            }
        
        let refreshControlDidRefresh = input.refreshControlDidRefresh
            // Refresh wallet balance when refershing transactions
            .do(onNext: { [weak self] in
                self?.updater.refreshBalance.onNext(())
                self?.updater.refreshRate.onNext(())
            })
        
        let refreshTransactionAction = refreshControlDidRefresh.flatMap { _ -> Driver<Action<Transactions>> in
            let source = geth.getTransactions(address: myAddress)
            return Action.makeDriver(source)
        }
        
        let getTransactionsAction = Driver.merge(getTransactionAction, refreshTransactionAction)
        
        let (latestTransactions, error) = (
            getTransactionsAction.elements.map { response -> [TransactionHistory] in
                return response.elements
                    // filters transactions executed more than a day ago,
                    // and shows only the first 5th.
                    .filter { $0.isExecutedLessThanDay }
                    .reversed()
                    .prefix(5)
                    .map { TransactionHistory(transaction: $0, myAddress: myAddress) }
            },
            getTransactionsAction.error
        )
        
        let isFetching = refreshTransactionAction.isExecuting
        
        return Output(
            latestTransactions: latestTransactions,
            isFetching: isFetching,
            error: error
        )
    }
}

import UIKit
import SideMenuController

class SignedInFlowController: BaseSignedInFlowController {
    
    // MARK: - Public properties
    
    static let userActionsTimeout: TimeInterval = 15 * 60
    static let backgroundTimeout: TimeInterval = 15 * 60
    
    private(set) var isAuthorized: Bool = true
    
    // MARK: - Private properties
    
    private let sideNavigationController: SideMenuController
    
    private let sideMenuViewController = SideMenu.ViewController()
    
    private let exploreTokensIdentifier: String = "ExploreTokens"
    private let sendPaymentIdentifier: String = "SendPayment"
    
    private var localAuthFlow: LocalAuthFlowController?
    private var timeoutSubscribeToken: TimerUIApplication.SubscribeToken = TimerUIApplication.SubscribeTokenInvalid
    private var backgroundTimer: Timer?
    private var backgroundToken: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    // MARK: - Callbacks
    
    let onSignOut: () -> Void
    let onLocalAuthRecoverySucceeded: () -> Void
    
    // MARK: -
    
    init(
        appController: AppControllerProtocol,
        flowControllerStack: FlowControllerStack,
        reposController: ReposController,
        managersController: ManagersController,
        userDataProvider: UserDataProviderProtocol,
        keychainDataProvider: KeychainDataProviderProtocol,
        rootNavigation: RootNavigationProtocol,
        onSignOut: @escaping () -> Void,
        onLocalAuthRecoverySucceeded: @escaping () -> Void
        ) {
        
        self.onSignOut = onSignOut
        self.onLocalAuthRecoverySucceeded = onLocalAuthRecoverySucceeded
        
        SideMenuController.preferences.drawing.menuButtonImage = UIImage(named: "Menu icon")
        SideMenuController.preferences.drawing.sidePanelPosition = .underCenterPanelLeft
        SideMenuController.preferences.drawing.sidePanelWidth = 300
        SideMenuController.preferences.drawing.menuButtonSize = 35
        SideMenuController.preferences.drawing.centerPanelShadow = true
        SideMenuController.preferences.animating.statusBarBehaviour = .horizontalPan
        SideMenuController.preferences.animating.transitionAnimator = nil
        
        self.sideNavigationController = SideMenuController()
        
        super.init(
            appController: appController,
            flowControllerStack: flowControllerStack,
            reposController: reposController,
            managersController: managersController,
            userDataProvider: userDataProvider,
            keychainDataProvider: keychainDataProvider,
            rootNavigation: rootNavigation
        )
        
        self.timeoutSubscribeToken = TimerUIApplication.subscribeForTimeoutNotification(handler: { [weak self] in
            self?.isAuthorized = false
            self?.stopUserActivityTimer()
            _ = self?.checkIsAuthorized()
        })
    }
    
    deinit {
        TimerUIApplication.unsubscribeFromTimeoutNotification(self.timeoutSubscribeToken)
        self.timeoutSubscribeToken = TimerUIApplication.SubscribeTokenInvalid
    }
    
    // MARK: - Public
    
    public func run() {
        self.setupSideMenu()
        self.showHomeScreen()
        self.startUserActivityTimer()
    }
    
    // MARK: - Overridden
    
    override func applicationDidEnterBackground() {
        guard self.localAuthFlow == nil else { return }
        
        self.startBackgroundTimer()
    }
    
    override func applicationWillEnterForeground() {
        guard self.localAuthFlow == nil else { return }
        
        self.stopBackgroundTimer()
    }
    
    override func applicationWillResignActive() {
        guard self.localAuthFlow == nil else { return }
        
        self.rootNavigation.showBackgroundCover()
    }
    
    override func applicationDidBecomeActive() {
        self.rootNavigation.hideBackgroundCover()
        
        if self.checkIsAuthorized() {
            self.currentFlowController?.applicationDidBecomeActive()
        }
    }
    
    // MARK: - Private
    
    private func showHomeScreen() {
        self.rootNavigation.setRootContent(
            self.sideNavigationController,
            transition: .fade,
            animated: true
        )
    }
    
    // MARK: - Setup
    
    private func setupSideMenu() {
        let headerModel = SideMenu.Model.HeaderModel(
            icon: #imageLiteral(resourceName: "Icon").withRenderingMode(.alwaysTemplate),
            title: self.getSideMenuHeaderTitle(),
            subTitle: self.userDataProvider.userEmail
        )
        
        let sections: [[SideMenu.Model.MenuItem]] = [
            [
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Dashboard icon"),
                    title: "Dashboard",
                    onSelected: { [weak self] in
                        self?.runDashboardFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Wallet icon"),
                    title: "Wallet",
                    onSelected: { [weak self] in
                        self?.runWalletFlow()
                })
            ],
            [
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Deposit icon"),
                    title: "Deposit",
                    onSelected: { [weak self] in
                        self?.runDepositFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Withdraw icon"),
                    title: "Withdraw",
                    onSelected: { [weak self] in
                        self?.runWithdrawFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Send icon"),
                    title: "Send",
                    onSelected: { [weak self] in
                        self?.runSendPaymentFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Explore funds icon.pdf"),
                    title: "Explore Funds",
                    onSelected: { [weak self] in
                        self?.runExploreFundsFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Explore tokens icon"),
                    title: "Explore Tokens",
                    onSelected: { [weak self] in
                        self?.runExploreTokensFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Trade icon"),
                    title: "Trades",
                    onSelected: { [weak self] in
                        self?.runTradeFlow()
                })
            ],
            [
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Settings icon"),
                    title: "Settings",
                    onSelected: { [weak self] in
                        self?.runSettingsFlow()
                }),
                SideMenu.Model.MenuItem(
                    iconImage: #imageLiteral(resourceName: "Sign out icon"),
                    title: "Sign out",
                    onSelected: { [weak self] in
                        self?.onSignOut()
                })
            ]
        ]
        
        SideMenu.Configurator.configure(
            viewController: self.sideMenuViewController,
            header: headerModel,
            sections: sections,
            routing: SideMenu.Routing()
        )
        
        self.sideNavigationController.embed(sideViewController: self.sideMenuViewController)
        self.runReposPreload()
        self.runDashboardFlow()
    }
    
    private func getSideMenuHeaderTitle() -> String {
        return AppInfoUtils.getValue(.bundleDisplayName, "TokenD")
    }
    
    // MARK: - Side Menu Navigation
    
    private func runReposPreload() {
        _ = self.reposController.assetsRepo.observeAssets()
        _ = self.reposController.balancesRepo.observeBalancesDetails()
    }
    
    private func runWalletFlow() {
        let walletDetailsFlowController = WalletDetailsFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = walletDetailsFlowController
        walletDetailsFlowController.run { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        }
    }
    
    private func runDashboardFlow() {
        let dashboardFlowController = DashboardFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = dashboardFlowController
        dashboardFlowController.run { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        }
    }
    
    private func runDepositFlow() {
        self.showDepositScreen { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        }
    }
    
    private func runExploreFundsFlow() {
        let flow = SalesFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(
            showRootScreen: { [weak self] (vc) in
                self?.sideNavigationController.embed(centerViewController: vc)
            },
            onShowWalletScreen: { [weak self] in
                self?.runWalletFlow()
        })
    }
    
    private func runExploreTokensFlow() {
        let exploreTokensFlowController = ExploreTokensFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = exploreTokensFlowController
        exploreTokensFlowController.run(showRootScreen: { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        })
    }
    
    private func runTradeFlow() {
        let flow = TradeFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(showRootScreen: { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        })
    }
    
    private func runSendPaymentFlow() {
        let flow = SendPaymentFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(
            showRootScreen: { [weak self] (vc) in
                self?.sideNavigationController.embed(centerViewController: vc)
            },
            onShowWalletScreen: { [weak self] in
                self?.runWalletFlow()
        })
    }
    
    private func runWithdrawFlow() {
        let flow = WithdrawFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(
            showRootScreen: { [weak self] (vc) in
                self?.sideNavigationController.embed(centerViewController: vc)
            },
            onShowWalletScreen: { [weak self] in
                self?.runWalletFlow()
        })
    }
    
    private func runSettingsFlow() {
        let flow = SettingsFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(showRootScreen: { [weak self] (vc) in
            self?.sideNavigationController.embed(centerViewController: vc)
        })
    }
    
    private func runSaleFlow() {
        let flow = SalesFlowController(
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            reposController: self.reposController,
            managersController: self.managersController,
            userDataProvider: self.userDataProvider,
            keychainDataProvider: self.keychainDataProvider,
            rootNavigation: self.rootNavigation
        )
        self.currentFlowController = flow
        flow.run(
            showRootScreen: { [weak self] (vc) in
                self?.sideNavigationController.embed(centerViewController: vc)
            },
            onShowWalletScreen: { [weak self] in
                self?.runWalletFlow()
        })
    }
    
    private func showDepositScreen(showRootScreen: ((_ vc: UIViewController) -> Void)?) {
        let navigationController: NavigationControllerProtocol = NavigationController()
        
        let viewController = DepositScene.ViewController()
        
        let qrCodeGenerator: DepositScene.QRCodeGeneratorProtocol = QRCodeGenerator()
        let dateFormatter: DepositScene.DateFormatterProtocol = DepositScene.DateFormatter()
        let assetsFetcher: DepositScene.AssetsFetcherProtocol = DepositScene.AssetsFetcher(
            assetsRepo: self.reposController.assetsRepo,
            balancesRepo: self.reposController.balancesRepo,
            accountRepo: self.reposController.accountRepo,
            externalSystemBalancesManager: self.managersController.externalSystemBalancesManager
        )
        let balanceBinder = BalanceBinder(
            balancesRepo: self.reposController.balancesRepo,
            accountRepo: self.reposController.accountRepo,
            externalSystemBalancesManager: self.managersController.externalSystemBalancesManager
        )
        let addressManager: DepositScene.AddressManagerProtocol = DepositScene.AddressManager(
            balanceBinder: balanceBinder
        )
        
        let routing = DepositScene.Routing(
            onShare: { (items) in
                let activityController = UIActivityViewController(
                    activityItems: items,
                    applicationActivities: nil
                )
                navigationController.present(
                    activityController,
                    animated: true,
                    completion: nil
                )},
            onError: { (message) in
                navigationController.showErrorMessage(message, completion: nil)
        })
        
        DepositScene.Configurator.configure(
            viewController: viewController,
            qrCodeGenerator: qrCodeGenerator,
            dateFormatter: dateFormatter,
            assetsFetcher: assetsFetcher,
            addressManager: addressManager,
            routing: routing
        )
        
        navigationController.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.font: Theme.Fonts.navigationBarBoldFont,
            NSAttributedStringKey.foregroundColor: Theme.Colors.textOnMainColor
        ]
        
        viewController.navigationItem.title = "Deposit"
        
        navigationController.setViewControllers([viewController], animated: false)
        
        if let showRoot = showRootScreen {
            showRoot(navigationController.getViewController())
        } else {
            self.rootNavigation.setRootContent(navigationController, transition: .fade, animated: false)
        }
    }
    
    // MARK: - Sign Out
    
    private func initiateSignOut() {
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to Sign Out and Erase All Data from device?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: "Sign Out and Erase",
            style: .default,
            handler: { [weak self] _ in
                self?.performSignOut()
        }))
        
        alert.addAction(UIAlertAction(
            title: "Cancel",
            style: .cancel,
            handler: nil
        ))
        
        self.sideNavigationController.present(alert, animated: true, completion: nil)
    }
    
    private func performSignOut() {
        let signOutWorker = RegisterScene.LocalSignInWorker(
            userDataManager: self.managersController.userDataManager,
            keychainManager: self.managersController.keychainManager
        )
        
        signOutWorker.performSignOut(completion: { [weak self] in
            self?.onSignOut()
        })
    }
    
    // MARK: - Timeout management
    
    private func startUserActivityTimer() {
        TimerUIApplication.startIdleTimer()
    }
    
    private func stopUserActivityTimer() {
        TimerUIApplication.stopIdleTimer()
    }
    
    private func startBackgroundTimer() {
        self.backgroundToken = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        self.backgroundTimer = Timer.scheduledTimer(
            withTimeInterval: SignedInFlowController.backgroundTimeout,
            repeats: false,
            block: { [weak self] _ in
                self?.isAuthorized = false
                self?.stopBackgroundTimer()
        })
    }
    
    private func stopBackgroundTimer() {
        self.backgroundTimer?.invalidate()
        self.backgroundTimer = nil
        UIApplication.shared.endBackgroundTask(self.backgroundToken)
        self.backgroundToken = UIBackgroundTaskInvalid
    }
    
    private func checkIsAuthorized() -> Bool {
        if !self.isAuthorized && UIApplication.shared.applicationState == .active {
            self.runLocalAuthByTimeout()
            return false
        }
        
        return true
    }
    
    private func runLocalAuthByTimeout() {
        guard self.localAuthFlow == nil else {
            return
        }
        
        let flow = LocalAuthFlowController(
            account: self.userDataProvider.account,
            appController: self.appController,
            flowControllerStack: self.flowControllerStack,
            rootNavigation: self.rootNavigation,
            userDataManager: self.managersController.userDataManager,
            keychainManager: self.managersController.keychainManager,
            onAuthorized: { [weak self] in
                self?.onLocalAuthSucceded()
            },
            onRecoverySucceeded: { [weak self] in
                self?.onLocalAuthRecoverySucceeded()
            },
            onSignOut: { [weak self] in
                self?.onSignOut()
        })
        self.localAuthFlow = flow
        flow.run(showRootScreen: nil)
    }
    
    private func onLocalAuthSucceded() {
        self.isAuthorized = true
        self.localAuthFlow = nil
        self.showHomeScreen()
        self.startUserActivityTimer()
    }
}
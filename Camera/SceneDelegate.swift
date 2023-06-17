import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        let rootVC = CameraViewController(
            useCase: CameraUseCase(
                state: CameraUseCase.State(),
                sessionClient: .liveValue,
                metalSessionClient: .ciFiltersClient
            )
        )
        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
    }
}


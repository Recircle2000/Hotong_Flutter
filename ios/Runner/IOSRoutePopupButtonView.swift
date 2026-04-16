import UIKit
import Flutter

// Flutter의 노선 선택 요청을 iOS 메뉴 버튼으로 연결하는 팩토리다.
final class IOSRoutePopupButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    IOSRoutePopupButtonView(
      frame: frame,
      viewId: viewId,
      args: args as? [String: Any],
      messenger: messenger
    )
  }
}

// UIButton + UIMenu를 이용해 iOS 스타일의 메뉴형 선택 버튼을 만든다.
final class IOSRoutePopupButtonView: NSObject, FlutterPlatformView {
  private struct RouteOption {
    let id: Int
    let title: String
  }

  private let container = UIView()
  private let button = UIButton(type: .system)
  private let channel: FlutterMethodChannel
  private var routes: [RouteOption] = []
  private var selectedRouteId: Int?

  init(
    frame: CGRect,
    viewId: Int64,
    args: [String: Any]?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "hsro/ios_route_popup_button_\(viewId)",
      binaryMessenger: messenger
    )

    super.init()

    configure(with: args)
    container.frame = frame
    container.backgroundColor = .clear

    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = .clear
    button.contentHorizontalAlignment = .center
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
    // 버튼 자체를 누르면 바로 메뉴가 열리게 한다.
    button.showsMenuAsPrimaryAction = true
    container.addSubview(button)

    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    rebuildMenu()
  }

  func view() -> UIView {
    container
  }

  private func configure(with args: [String: Any]?) {
    if let rawRoutes = args?["routes"] as? [Any] {
      routes = rawRoutes.compactMap { item in
        guard let dictionary = item as? [String: Any],
              let id = dictionary["id"] as? Int,
              let title = dictionary["title"] as? String else {
          return nil
        }

        return RouteOption(id: id, title: title)
      }
    }

    if let routeId = args?["selectedRouteId"] as? Int, routeId >= 0 {
      selectedRouteId = routeId
    }
  }

  private func rebuildMenu() {
    button.isEnabled = !routes.isEmpty
    button.menu = UIMenu(children: routes.map { route in
      UIAction(
        title: route.title,
        state: route.id == selectedRouteId ? .on : .off
      ) { [weak self] _ in
        self?.handleSelection(route.id)
      }
    })

    updateButtonAppearance()
  }

  private func handleSelection(_ routeId: Int) {
    selectedRouteId = routeId
    rebuildMenu()
    channel.invokeMethod("onChanged", arguments: routeId)
  }

  private func updateButtonAppearance() {
    let selectedRoute = routes.first { $0.id == selectedRouteId }
    let title = selectedRoute?.title ?? "노선을 선택하세요"
    let foregroundColor = selectedRoute == nil ? UIColor.secondaryLabel : UIColor.label
    let chevronImage = UIImage(systemName: "chevron.down")

    if #available(iOS 15.0, *) {
      var configuration = button.configuration ?? UIButton.Configuration.plain()
      configuration.title = title
      configuration.image = chevronImage
      configuration.imagePlacement = .trailing
      configuration.imagePadding = 6
      configuration.baseForegroundColor = foregroundColor
      configuration.contentInsets = .zero
      button.configuration = configuration
    } else {
      button.setTitle(title, for: .normal)
      button.setTitleColor(foregroundColor, for: .normal)
      button.setImage(chevronImage, for: .normal)
      button.tintColor = foregroundColor
      button.semanticContentAttribute = .forceRightToLeft
      button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
    }
  }
}

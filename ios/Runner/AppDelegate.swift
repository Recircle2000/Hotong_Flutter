import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var arrivalStationPickerChannel: FlutterMethodChannel?
  private var alertDialogChannel: FlutterMethodChannel?
  private var favoriteJourneyMenuChannel: FlutterMethodChannel?
  private var favoriteJourneyMenuPresenter: AnyObject?
  private var stationInfoMenuChannel: FlutterMethodChannel?
  private var stationInfoMenuPresenter: AnyObject?
  private var arrivalStationPickerDismissDelegate: IOSArrivalStationPickerDismissDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // UIScene이 생성한 Flutter 엔진에 iOS 네이티브 PlatformView와 채널을 등록한다.
    registerPlatformViews(with: engineBridge.pluginRegistry)
    registerMethodChannels(binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }

  private func registerPlatformViews(with pluginRegistry: FlutterPluginRegistry) {
    // iOS compact 날짜 선택기
    if let datePickerRegistrar = pluginRegistry.registrar(forPlugin: "IOSCompactDatePicker") {
      datePickerRegistrar.register(
        IOSCompactDatePickerFactory(messenger: datePickerRegistrar.messenger()),
        withId: "hsro/ios_compact_date_picker"
      )
    }

    // iOS 메뉴형 노선 선택 버튼
    if let routeButtonRegistrar = pluginRegistry.registrar(forPlugin: "IOSRoutePopupButton") {
      routeButtonRegistrar.register(
        IOSRoutePopupButtonFactory(messenger: routeButtonRegistrar.messenger()),
        withId: "hsro/ios_route_popup_button"
      )
    }
  }

  private func registerMethodChannels(binaryMessenger: FlutterBinaryMessenger) {
    registerArrivalStationPickerChannel(binaryMessenger: binaryMessenger)
    // Flutter MethodChannel은 기능별로 분리해두면 호출 인자와 응답 타입을 관리하기 쉽다.
    registerAlertDialogChannel(binaryMessenger: binaryMessenger)
    registerFavoriteJourneyMenuChannel(binaryMessenger: binaryMessenger)
    registerStationInfoMenuChannel(binaryMessenger: binaryMessenger)
  }

  private func registerArrivalStationPickerChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "hsro/ios_arrival_station_picker",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self = self else {
        result(FlutterError(
          code: "channel_unavailable",
          message: "도착 정류장 선택기 채널을 사용할 수 없습니다.",
          details: nil
        ))
        return
      }

      self.showArrivalStationPicker(call: call, result: result)
    }

    arrivalStationPickerChannel = channel
  }

  private func registerAlertDialogChannel(binaryMessenger: FlutterBinaryMessenger) {
    // Flutter 쪽 MethodChannel('hsro/ios_alert_dialog')와 같은 이름으로 등록한다.
    let channel = FlutterMethodChannel(
      name: "hsro/ios_alert_dialog",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      // 지금 채널에서는 iOS 기본 알림창 표시 요청 하나만 처리한다.
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self = self else {
        result(FlutterError(
          code: "channel_unavailable",
          message: "알림 다이얼로그 채널을 사용할 수 없습니다.",
          details: nil
        ))
        return
      }

      self.showAlertDialog(call: call, result: result)
    }

    alertDialogChannel = channel
  }

  private func registerFavoriteJourneyMenuChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "hsro/ios_favorite_journey_menu",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self = self else {
        result(FlutterError(
          code: "channel_unavailable",
          message: "즐겨찾기 메뉴 채널을 사용할 수 없습니다.",
          details: nil
        ))
        return
      }

      self.showFavoriteJourneyMenu(call: call, result: result)
    }

    favoriteJourneyMenuChannel = channel
  }

  private func registerStationInfoMenuChannel(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "hsro/ios_station_info_menu",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "show" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self = self else {
        result(FlutterError(
          code: "channel_unavailable",
          message: "정류장 정보 메뉴 채널을 사용할 수 없습니다.",
          details: nil
        ))
        return
      }

      self.showStationInfoMenu(call: call, result: result)
    }

    stationInfoMenuChannel = channel
  }

  private func showArrivalStationPicker(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let rawStations = args["stations"] as? [Any] else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "도착 정류장 목록이 올바르지 않습니다.",
        details: nil
      ))
      return
    }

    let stations = rawStations.compactMap { item -> IOSArrivalStationOption? in
      guard let dictionary = item as? [String: Any],
            let id = intValue(from: dictionary["id"]),
            let title = dictionary["title"] as? String else {
        return nil
      }

      return IOSArrivalStationOption(id: id, title: title)
    }

    guard !stations.isEmpty else {
      result(nil)
      return
    }

    DispatchQueue.main.async { [weak self] in
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "presentation_failed",
          message: "도착 정류장 선택기를 표시할 수 없습니다.",
          details: nil
        ))
        return
      }

      let title = args["title"] as? String ?? "도착 기준 정류장"
      let cancelTitle = args["cancelTitle"] as? String ?? "취소"
      let selectedStationId = self.intValue(from: args["selectedStationId"])
      let resultBox = IOSSingleFlutterResult(result)
      let pickerController = IOSArrivalStationPickerController(
        title: title,
        cancelTitle: cancelTitle,
        stations: stations,
        selectedStationId: selectedStationId,
        onSelect: { [weak self] stationId in
          resultBox.complete(stationId)
          self?.arrivalStationPickerDismissDelegate = nil
        },
        onCancel: { [weak self] in
          resultBox.complete(nil)
          self?.arrivalStationPickerDismissDelegate = nil
        }
      )
      let navigationController = UINavigationController(rootViewController: pickerController)
      navigationController.modalPresentationStyle = .pageSheet

      if #available(iOS 15.0, *),
         let sheet = navigationController.sheetPresentationController {
        sheet.detents = [.medium()]
        sheet.selectedDetentIdentifier = .medium
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        sheet.preferredCornerRadius = 20
      }

      let dismissDelegate = IOSArrivalStationPickerDismissDelegate(
        resultBox: resultBox
      ) { [weak self] in
        self?.arrivalStationPickerDismissDelegate = nil
      }
      self.arrivalStationPickerDismissDelegate = dismissDelegate

      if let popover = navigationController.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.maxY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }

      navigationController.presentationController?.delegate = dismissDelegate
      presenter.present(navigationController, animated: true)
    }
  }

  private func showAlertDialog(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Dart에서 넘긴 Map 인자를 Swift에서 사용할 타입으로 꺼낸다.
    guard let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let message = args["message"] as? String else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "알림 다이얼로그 문구가 올바르지 않습니다.",
        details: nil
      ))
      return
    }

    let buttonTitle = args["buttonTitle"] as? String ?? "확인"

    DispatchQueue.main.async { [weak self] in
      // UIKit 화면 표시는 항상 현재 최상단 ViewController에서 메인 스레드로 수행한다.
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "presentation_failed",
          message: "알림 다이얼로그를 표시할 수 없습니다.",
          details: nil
        ))
        return
      }

      let alertController = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .alert
      )
      alertController.addAction(UIAlertAction(title: buttonTitle, style: .default) { _ in
        // 사용자가 확인을 누른 뒤에 Dart의 await가 끝나도록 result를 완료한다.
        result(nil)
      })

      presenter.present(alertController, animated: true)
    }
  }

  private func showFavoriteJourneyMenu(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "즐겨찾기 메뉴 문구가 올바르지 않습니다.",
        details: nil
      ))
      return
    }

    let title = args["title"] as? String
    let renameTitle = args["renameTitle"] as? String ?? "이름 변경"
    let deleteTitle = args["deleteTitle"] as? String ?? "삭제"
    let cancelTitle = args["cancelTitle"] as? String ?? "취소"
    let sourceX = (args["sourceX"] as? NSNumber)?.doubleValue
    let sourceY = (args["sourceY"] as? NSNumber)?.doubleValue
    let sourceWidth = (args["sourceWidth"] as? NSNumber)?.doubleValue
    let sourceHeight = (args["sourceHeight"] as? NSNumber)?.doubleValue

    DispatchQueue.main.async { [weak self] in
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "presentation_failed",
          message: "즐겨찾기 메뉴를 표시할 수 없습니다.",
          details: nil
        ))
        return
      }

      if #available(iOS 16.0, *),
         let sourceX = sourceX,
         let sourceY = sourceY,
         let sourceWidth = sourceWidth,
         let sourceHeight = sourceHeight {
        let resultBox = IOSSingleFlutterResult(result)
        let sourcePoint = CGPoint(
          x: sourceX + sourceWidth / 2,
          y: sourceY + sourceHeight / 2
        )
        let menuPresenter = IOSFavoriteJourneyMenuPresenter(
          sourceView: presenter.view,
          sourcePoint: sourcePoint,
          renameTitle: renameTitle,
          deleteTitle: deleteTitle,
          resultBox: resultBox
        ) { [weak self] in
          self?.favoriteJourneyMenuPresenter = nil
        }
        self.favoriteJourneyMenuPresenter = menuPresenter
        menuPresenter.present()
        return
      }

      // iOS 15 이하에서는 컨텍스트 메뉴 API가 없어 action sheet를 사용한다.
      let menu = UIAlertController(
        title: title,
        message: nil,
        preferredStyle: .actionSheet
      )
      menu.addAction(UIAlertAction(title: renameTitle, style: .default) { _ in
        result("rename")
      })
      menu.addAction(UIAlertAction(title: deleteTitle, style: .destructive) { _ in
        result("delete")
      })
      menu.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
        result(nil)
      })

      // iPad에서 action sheet는 popover 위치를 반드시 지정해야 한다.
      if let popover = menu.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.maxY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }

      presenter.present(menu, animated: true)
    }
  }

  private func showStationInfoMenu(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let rawStations = args["stations"] as? [Any] else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "정류장 정보 메뉴 항목이 올바르지 않습니다.",
        details: nil
      ))
      return
    }

    let stations = rawStations.compactMap { item -> IOSStationInfoOption? in
      guard let dictionary = item as? [String: Any],
            let id = intValue(from: dictionary["id"]),
            let title = dictionary["title"] as? String else {
        return nil
      }
      return IOSStationInfoOption(id: id, title: title)
    }

    guard !stations.isEmpty else {
      result(nil)
      return
    }

    let title = args["title"] as? String ?? "어떤 정류장 정보를 볼까요?"
    let cancelTitle = args["cancelTitle"] as? String ?? "취소"
    let sourceX = (args["sourceX"] as? NSNumber)?.doubleValue
    let sourceY = (args["sourceY"] as? NSNumber)?.doubleValue
    let sourceWidth = (args["sourceWidth"] as? NSNumber)?.doubleValue
    let sourceHeight = (args["sourceHeight"] as? NSNumber)?.doubleValue

    DispatchQueue.main.async { [weak self] in
      guard let self = self, let presenter = self.topViewController() else {
        result(FlutterError(
          code: "presentation_failed",
          message: "정류장 정보 메뉴를 표시할 수 없습니다.",
          details: nil
        ))
        return
      }

      if #available(iOS 16.0, *),
         let sourceX = sourceX,
         let sourceY = sourceY,
         let sourceWidth = sourceWidth,
         let sourceHeight = sourceHeight {
        let resultBox = IOSSingleFlutterResult(result)
        let sourcePoint = CGPoint(
          x: sourceX + sourceWidth / 2,
          y: sourceY + sourceHeight / 2
        )
        let menuPresenter = IOSStationInfoMenuPresenter(
          sourceView: presenter.view,
          sourcePoint: sourcePoint,
          title: title,
          stations: stations,
          resultBox: resultBox
        ) { [weak self] in
          self?.stationInfoMenuPresenter = nil
        }
        self.stationInfoMenuPresenter = menuPresenter
        menuPresenter.present()
        return
      }

      let menu = UIAlertController(
        title: title,
        message: nil,
        preferredStyle: .actionSheet
      )
      for station in stations {
        menu.addAction(UIAlertAction(title: station.title, style: .default) { _ in
          result(station.id)
        })
      }
      menu.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
        result(nil)
      })

      if let popover = menu.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.maxY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }

      presenter.present(menu, animated: true)
    }
  }

  private func topViewController(from root: UIViewController? = nil) -> UIViewController? {
    let rootViewController = root ?? keyWindow?.rootViewController

    if let navigationController = rootViewController as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }

    if let tabBarController = rootViewController as? UITabBarController,
       let selectedViewController = tabBarController.selectedViewController {
      return topViewController(from: selectedViewController)
    }

    if let presentedViewController = rootViewController?.presentedViewController {
      return topViewController(from: presentedViewController)
    }

    return rootViewController
  }

  private var keyWindow: UIWindow? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    }

    return window
  }

  private func intValue(from value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }

    if let value = value as? Int64 {
      return Int(value)
    }

    if let value = value as? NSNumber {
      return value.intValue
    }

    return nil
  }
}

private struct IOSArrivalStationOption {
  let id: Int
  let title: String
}

private struct IOSStationInfoOption {
  let id: Int
  let title: String
}

private final class IOSArrivalStationPickerController: UITableViewController {
  private static let reuseIdentifier = "IOSArrivalStationCell"

  private let pickerTitle: String
  private let cancelTitle: String
  private let stations: [IOSArrivalStationOption]
  private let selectedStationId: Int?
  private let onSelect: (Int) -> Void
  private let onCancel: () -> Void
  private var didScrollToSelectedStation = false

  init(
    title: String,
    cancelTitle: String,
    stations: [IOSArrivalStationOption],
    selectedStationId: Int?,
    onSelect: @escaping (Int) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.pickerTitle = title
    self.cancelTitle = cancelTitle
    self.stations = stations
    self.selectedStationId = selectedStationId
    self.onSelect = onSelect
    self.onCancel = onCancel

    super.init(style: .insetGrouped)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = pickerTitle
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: cancelTitle,
      style: .plain,
      target: self,
      action: #selector(handleCancel)
    )

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.reuseIdentifier)
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 52
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    scrollToSelectedStationIfNeeded()
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    stations.count
  }

  override func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: Self.reuseIdentifier,
      for: indexPath
    )
    let station = stations[indexPath.row]

    if #available(iOS 14.0, *) {
      var content = cell.defaultContentConfiguration()
      content.text = station.title
      content.textProperties.numberOfLines = 2
      cell.contentConfiguration = content
    } else {
      cell.textLabel?.text = station.title
      cell.textLabel?.numberOfLines = 2
    }

    cell.accessoryType = station.id == selectedStationId ? .checkmark : .none
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    let station = stations[indexPath.row]
    onSelect(station.id)
    dismiss(animated: true)
  }

  @objc private func handleCancel() {
    onCancel()
    dismiss(animated: true)
  }

  private func scrollToSelectedStationIfNeeded() {
    guard !didScrollToSelectedStation,
          let selectedStationId = selectedStationId,
          let selectedIndex = stations.firstIndex(where: { $0.id == selectedStationId }) else {
      return
    }

    didScrollToSelectedStation = true
    tableView.scrollToRow(
      at: IndexPath(row: selectedIndex, section: 0),
      at: .middle,
      animated: false
    )
  }
}

private final class IOSSingleFlutterResult {
  private let result: FlutterResult
  private var didComplete = false

  init(_ result: @escaping FlutterResult) {
    self.result = result
  }

  func complete(_ value: Any?) {
    guard !didComplete else {
      return
    }

    didComplete = true
    result(value)
  }
}

private final class IOSArrivalStationPickerDismissDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
  private let resultBox: IOSSingleFlutterResult
  private let onDismiss: () -> Void

  init(
    resultBox: IOSSingleFlutterResult,
    onDismiss: @escaping () -> Void
  ) {
    self.resultBox = resultBox
    self.onDismiss = onDismiss
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    resultBox.complete(nil)
    onDismiss()
  }
}

@available(iOS 16.0, *)
private final class IOSFavoriteJourneyMenuPresenter: NSObject, UIEditMenuInteractionDelegate {
  private weak var sourceView: UIView?
  private let sourcePoint: CGPoint
  private let renameTitle: String
  private let deleteTitle: String
  private let resultBox: IOSSingleFlutterResult
  private let onDismiss: () -> Void
  private var didSelectAction = false
  private lazy var interaction = UIEditMenuInteraction(delegate: self)

  init(
    sourceView: UIView,
    sourcePoint: CGPoint,
    renameTitle: String,
    deleteTitle: String,
    resultBox: IOSSingleFlutterResult,
    onDismiss: @escaping () -> Void
  ) {
    self.sourceView = sourceView
    self.sourcePoint = sourcePoint
    self.renameTitle = renameTitle
    self.deleteTitle = deleteTitle
    self.resultBox = resultBox
    self.onDismiss = onDismiss
    super.init()
  }

  func present() {
    guard let sourceView = sourceView else {
      resultBox.complete(nil)
      onDismiss()
      return
    }

    sourceView.addInteraction(interaction)
    interaction.presentEditMenu(
      with: UIEditMenuConfiguration(identifier: nil, sourcePoint: sourcePoint)
    )
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions: [UIMenuElement]
  ) -> UIMenu? {
    let renameAction = UIAction(title: renameTitle) { [weak self] _ in
      self?.complete(with: "rename")
    }
    let deleteAction = UIAction(
      title: deleteTitle,
      attributes: .destructive
    ) { [weak self] _ in
      self?.complete(with: "delete")
    }

    return UIMenu(children: [renameAction, deleteAction])
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    willDismissMenuFor configuration: UIEditMenuConfiguration,
    animator: any UIEditMenuInteractionAnimating
  ) {
    animator.addCompletion { [weak self] in
      guard let self = self else { return }
      if !self.didSelectAction {
        self.resultBox.complete(nil)
      }
      self.sourceView?.removeInteraction(self.interaction)
      self.onDismiss()
    }
  }

  private func complete(with action: String) {
    didSelectAction = true
    resultBox.complete(action)
  }
}

@available(iOS 16.0, *)
private final class IOSStationInfoMenuPresenter: NSObject, UIEditMenuInteractionDelegate {
  private weak var sourceView: UIView?
  private let sourcePoint: CGPoint
  private let menuTitle: String
  private let stations: [IOSStationInfoOption]
  private let resultBox: IOSSingleFlutterResult
  private let onDismiss: () -> Void
  private var didSelectStation = false
  private lazy var interaction = UIEditMenuInteraction(delegate: self)

  init(
    sourceView: UIView,
    sourcePoint: CGPoint,
    title: String,
    stations: [IOSStationInfoOption],
    resultBox: IOSSingleFlutterResult,
    onDismiss: @escaping () -> Void
  ) {
    self.sourceView = sourceView
    self.sourcePoint = sourcePoint
    self.menuTitle = title
    self.stations = stations
    self.resultBox = resultBox
    self.onDismiss = onDismiss
    super.init()
  }

  func present() {
    guard let sourceView = sourceView else {
      resultBox.complete(nil)
      onDismiss()
      return
    }

    sourceView.addInteraction(interaction)
    interaction.presentEditMenu(
      with: UIEditMenuConfiguration(identifier: nil, sourcePoint: sourcePoint)
    )
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions: [UIMenuElement]
  ) -> UIMenu? {
    let actions = stations.map { station in
      UIAction(
        title: station.title,
        image: UIImage(systemName: "mappin.and.ellipse")
      ) { [weak self] _ in
        self?.complete(with: station.id)
      }
    }
    return UIMenu(title: menuTitle, children: actions)
  }

  func editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    willDismissMenuFor configuration: UIEditMenuConfiguration,
    animator: any UIEditMenuInteractionAnimating
  ) {
    animator.addCompletion { [weak self] in
      guard let self = self else { return }
      if !self.didSelectStation {
        self.resultBox.complete(nil)
      }
      self.sourceView?.removeInteraction(self.interaction)
      self.onDismiss()
    }
  }

  private func complete(with stationId: Int) {
    didSelectStation = true
    resultBox.complete(stationId)
  }
}

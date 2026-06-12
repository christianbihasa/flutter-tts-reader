import UIKit
import Flutter
import PDFKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let pdfChannel = FlutterMethodChannel(name: "io.github.christianbihasa/pdf_parser",
                                              binaryMessenger: controller.binaryMessenger)
    
    pdfChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
        return
      }
      
      let url = URL(fileURLWithPath: path)
      guard let document = PDFDocument(url: url) else {
        result(FlutterError(code: "DOC_LOAD_FAILED", message: "Could not open PDF document", details: nil))
        return
      }
      
      if call.method == "getJerryPageCount" {
        result(document.pageCount)
      } else if call.method == "extractPageText" {
        guard let pageNumber = args["pageNumber"] as? Int, pageNumber < document.pageCount else {
          result(FlutterError(code: "INVALID_PAGE", message: "Out of bounds page index", details: nil))
          return
        }
        if let page = document.page(at: pageNumber) {
          result(page.string ?? "")
        } else {
          result("")
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
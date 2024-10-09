import Flutter
import UIKit
import Photos

public class SwiftScreenshotCallbackPlugin: NSObject, FlutterPlugin {
    static var channel: FlutterMethodChannel?
    
    static var observer: NSObjectProtocol?;
    
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        channel  = FlutterMethodChannel(name: "flutter.moum/screenshot_callback", binaryMessenger: registrar.messenger())
        observer = nil;
        let instance = SwiftScreenshotCallbackPlugin()
        if let channel = channel {
            registrar.addMethodCallDelegate(instance, channel: channel)
        }
        
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if(call.method == "initialize"){
            if(SwiftScreenshotCallbackPlugin.observer != nil) {
                NotificationCenter.default.removeObserver(SwiftScreenshotCallbackPlugin.observer!);
                SwiftScreenshotCallbackPlugin.observer = nil;
            }
            SwiftScreenshotCallbackPlugin.observer = NotificationCenter.default.addObserver(
                forName: UIApplication.userDidTakeScreenshotNotification,
                object: nil,
                queue: .main) { notification in
                    self.getScreenImage()
                    result("screen shot called")
                }
            result("initialize")
        }else if(call.method == "dispose"){
            if(SwiftScreenshotCallbackPlugin.observer != nil) {
                NotificationCenter.default.removeObserver(SwiftScreenshotCallbackPlugin.observer!);
                SwiftScreenshotCallbackPlugin.observer = nil;
            }
            result("dispose")
        }else{
            result("")
        }
    }
    
    deinit {
        if(SwiftScreenshotCallbackPlugin.observer != nil) {
            NotificationCenter.default.removeObserver(SwiftScreenshotCallbackPlugin.observer!);
            SwiftScreenshotCallbackPlugin.observer = nil;
        }
    }
    
    private func dataWithScreenshotInPNGFormat() -> Data?{
        let imageSize: CGSize
        let orientation: UIInterfaceOrientation = UIApplication.shared.statusBarOrientation
        if orientation.isPortrait {
            imageSize = UIScreen.main.bounds.size
        }else{
            imageSize = CGSize(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.size.width)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 0
        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        let image = renderer.image { context in
            for window: UIWindow in UIApplication.shared.windows {
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: window.center.x, y: window.center.y)
                context.cgContext.concatenate(window.transform)
                context.cgContext.translateBy(x: -window.bounds.size.width * window.layer.anchorPoint.x, y: -window.bounds.size.height * window.layer.anchorPoint.y)
                if orientation == .landscapeLeft{
                    context.cgContext.rotate(by: CGFloat(Double.pi / 2))
                    context.cgContext.translateBy(x: 0, y: -imageSize.width)
                }else if orientation == .landscapeRight{
                    context.cgContext.rotate(by: -CGFloat(Double.pi / 2))
                    context.cgContext.translateBy(x: -imageSize.height, y: 0)
                }else if orientation == .portraitUpsideDown{
                    context.cgContext.rotate(by: -CGFloat(Double.pi))
                    context.cgContext.translateBy(x: -imageSize.width, y: -imageSize.height)
                }
                
                if window.responds(to: #selector(UIView.drawHierarchy(in:afterScreenUpdates:))){
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }else{
                    window.layer.render(in: context.cgContext)
                }
                context.cgContext.restoreGState()
            }
        }
        
        return image.jpegData(compressionQuality: 0.7)
    }
    
    func getScreenImage(){
        if let channel = SwiftScreenshotCallbackPlugin.channel {
            let screenShotImageData = dataWithScreenshotInPNGFormat();
            if screenShotImageData != nil {
                var documentsPath = NSTemporaryDirectory()
                let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                
                documentsPath = "\(documentsPath)screenshot"
                let fileManager = FileManager.default
                let hasDir = fileManager.fileExists(atPath: documentsPath)
                if hasDir == false {
                    do {
                        try fileManager.createDirectory(atPath: documentsPath, withIntermediateDirectories: true, attributes: nil)
                    } catch let err {
                        channel.invokeMethod("onCallback", arguments: nil)
                        return
                    }
                }
                
                let fileName = "\(documentsPath)/\(String(timestamp))temp.jpg"
                do {
                    try screenShotImageData!.write(to: URL(fileURLWithPath: fileName))
                    channel.invokeMethod("onCallback", arguments: fileName)
                } catch let err {
                    channel.invokeMethod("onCallback", arguments: nil)
                }
            } else {
                channel.invokeMethod("onCallback", arguments: nil)
            }
        }
    }
    
    func checkScreenShot(){
        if let channel = SwiftScreenshotCallbackPlugin.channel {
            let opt = PHFetchOptions()
            opt.sortDescriptors = [NSSortDescriptor.init(key: "screenShot", ascending: false)]
            let assetArr = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: nil)
            let asset = assetArr.lastObject
            let imageManager = PHImageManager.default()
            if asset != nil {
                imageManager.requestImageData(for: asset!, options: nil) { imagedata, dataUTI, orient, info in
                    var screenShotImageData = imagedata
                    if screenShotImageData != nil {
                        var documentsPath = NSTemporaryDirectory()
                        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
                        
                        documentsPath = "\(documentsPath)screenshot"
                        let fileManager = FileManager.default
                        let hasDir = fileManager.fileExists(atPath: documentsPath)
                        if hasDir == false {
                            do {
                                try fileManager.createDirectory(atPath: documentsPath, withIntermediateDirectories: true, attributes: nil)
                            } catch let err {
                                channel.invokeMethod("onCallback", arguments: nil)
                                return
                            }
                        }
                        
                        let fileName = "\(documentsPath)/\(String(timestamp))temp.jpg"
                        let image = UIImage.init(data: screenShotImageData!)
                        let compressData = image?.jpegData(compressionQuality: 0.8)
                        if compressData != nil {
                            screenShotImageData = compressData
                        }
                        do {
                            try screenShotImageData!.write(to: URL(fileURLWithPath: fileName))
                            channel.invokeMethod("onCallback", arguments: fileName)
                        } catch let err {
                            channel.invokeMethod("onCallback", arguments: nil)
                        }
                    } else {
                        channel.invokeMethod("onCallback", arguments: nil)
                    }
                }
            } else {
                channel.invokeMethod("onCallback", arguments: nil)
            }
        }
    }
    
    func ScreenShotXLLog(_ message:String, file:String = #file, function:String = #function,
                         line:Int32 = #line) {
        let fileName = (file as NSString).lastPathComponent
        ScreenshotCallbackPlugin.xlLog(withLevel: 2, moduleName: "flutter_iOS_plugin_screenshot", fileName: fileName, lineNumber: line, funcName: function, message: message)
    }
}

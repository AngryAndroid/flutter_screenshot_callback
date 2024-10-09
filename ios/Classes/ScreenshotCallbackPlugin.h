#import <Flutter/Flutter.h>

@interface ScreenshotCallbackPlugin : NSObject<FlutterPlugin>

+ (void)xlLogWithLevel:(NSInteger)logLevel moduleName:(NSString *)moduleName fileName:(NSString *)fileName lineNumber:(int)lineNumber funcName:(NSString *)funcName message:(NSString *)message;

@end

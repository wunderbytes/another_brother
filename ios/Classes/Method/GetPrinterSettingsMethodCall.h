//
//  GetPrinterSettingsMethodCall.h
//  another_brother
//
//  Reads the current printer configuration via the legacy
//  BRPtouchPrinter getPrinterSettings:require: API. The newer
//  BRLMPrinterDriver does not expose this functionality.
//

#ifndef GetPrinterSettingsMethodCall_h
#define GetPrinterSettingsMethodCall_h

#import <Flutter/Flutter.h>
#import <BRLMPrinterKit/BRPtouchPrinterKit.h>
#import "BrotherUtils.h"

@interface GetPrinterSettingsMethodCall : NSObject

@property (strong, nonatomic) FlutterMethodCall* call;
@property (strong, nonatomic) FlutterResult result;
@property (class, nonatomic, assign, readonly) NSString * METHOD_NAME;

- (instancetype)initWithCall:(FlutterMethodCall *)call
                  result:(FlutterResult) result;

- (void) execute;
@end

#endif /* GetPrinterSettingsMethodCall_h */

//
//  UpdatePrinterSettingsMethodCall.h
//  another_brother
//

#ifndef UpdatePrinterSettingsMethodCall_h
#define UpdatePrinterSettingsMethodCall_h

#import <Flutter/Flutter.h>
#import "BrotherUtils.h"

@interface UpdatePrinterSettingsMethodCall : NSObject

@property (strong, nonatomic) FlutterMethodCall* call;
@property (strong, nonatomic) FlutterResult result;
@property (class, nonatomic, assign, readonly) NSString * METHOD_NAME;

- (instancetype)initWithCall:(FlutterMethodCall *)call
                      result:(FlutterResult) result;

- (void) execute;

@end

#endif /* UpdatePrinterSettingsMethodCall_h */

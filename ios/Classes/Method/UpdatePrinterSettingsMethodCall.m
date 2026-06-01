//
//  UpdatePrinterSettingsMethodCall.m
//  another_brother
//
//  Mirrors the Android UpdatePrinterSettingsMethodCall behavior. The newer
//  BRLMPrinterDriver API used elsewhere in the plugin does not expose
//  setPrinterSettings:, so we drop down to the legacy BRPtouchPrinter API.
//
//  Per the Brother iOS SDK reference manual, the correct call sequence is:
//    1. initWithPrinterName:interface: (e.g. @"QL-820NWB", no "Brother " prefix)
//    2. setIPAddress: / setupForBluetoothDeviceWithSerialNumber: /
//       setBLEAdvertiseLocalName: depending on the connection type
//    3. startCommunication
//    4. setPrinterSettings:
//    5. endCommunication
//

#import <Foundation/Foundation.h>
#import "UpdatePrinterSettingsMethodCall.h"
#import "LegacyPrinterUtils.h"

@implementation UpdatePrinterSettingsMethodCall
static NSString * METHOD_NAME = @"updatePrinterSettings";

+ (NSString *) METHOD_NAME {
    return METHOD_NAME;
}

- (instancetype)initWithCall:(FlutterMethodCall *)call
                      result:(FlutterResult) result {
    self = [super init];
    if (self) {
        _call = call;
        _result = result;
    }
    return self;
}

- (void)execute {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{

        NSDictionary<NSString *, NSObject *> * dartPrintInfo = self->_call.arguments[@"printInfo"];
        NSDictionary * dartSettings = self->_call.arguments[@"settings"];

        NSLog(@"[another_brother][updatePrinterSettings] Raw settings dict (count=%lu): %@",
              (unsigned long)[dartSettings count], dartSettings);

        BRPtouchPrinter * printer = [LegacyPrinterUtils brPtouchPrinterFromPrintInfoMap:dartPrintInfo];

        // Build the dictionary expected by setPrinterSettings:. Keys are the
        // PrinterSettingItem enum raw values wrapped in NSNumber, values are
        // strings.
        NSMutableDictionary<NSNumber *, NSString *> * iosSettings = [NSMutableDictionary dictionaryWithCapacity:[dartSettings count]];
        NSUInteger skippedEntries = 0;
        for (id rawKey in dartSettings) {
            id rawValue = [dartSettings objectForKey:rawKey];

            NSNumber * settingId = [LegacyPrinterUtils settingIdFromRawKey:rawKey];
            NSString * value = nil;
            if ([rawValue isKindOfClass:[NSString class]]) {
                value = (NSString *)rawValue;
            } else if ([rawValue isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)rawValue stringValue];
            }

            if (settingId == nil || value == nil) {
                NSLog(@"[another_brother][updatePrinterSettings] Skipping entry rawKey=%@ (class=%@) rawValue=%@ (class=%@)",
                      rawKey, NSStringFromClass([rawKey class]),
                      rawValue, NSStringFromClass([rawValue class]));
                skippedEntries += 1;
                continue;
            }

            [iosSettings setObject:value forKey:settingId];
        }

        NSLog(@"[another_brother][updatePrinterSettings] Built iOS settings dict (count=%lu, skipped=%lu): %@",
              (unsigned long)[iosSettings count], (unsigned long)skippedEntries, iosSettings);

        if ([iosSettings count] == 0) {
            NSLog(@"[another_brother][updatePrinterSettings] No valid settings to apply, returning ERROR_INVALID_PARAMETER without calling the SDK.");
            NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:@"ERROR_INVALID_PARAMETER"];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self->_result(status);
            });
            return;
        }

        // The Brother iOS SDK manual says startCommunication must be called
        // before any API that talks to the printer. The "Communication cmd
        // error" we used to see on the device was caused by initializing the
        // printer with the wrong model name ("Brother QL-820NWB" instead of
        // "QL-820NWB"), which made the SDK build malformed commands.
        NSLog(@"[another_brother][updatePrinterSettings] Calling startCommunication...");
        BOOL connOpened = [printer startCommunication];
        if (!connOpened) {
            NSLog(@"[another_brother][updatePrinterSettings] startCommunication returned NO, aborting.");
            NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:@"ERROR_COMMUNICATION_ERROR"];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self->_result(status);
            });
            return;
        }

        NSLog(@"[another_brother][updatePrinterSettings] Calling [BRPtouchPrinter setPrinterSettings:] with %lu entries...",
              (unsigned long)[iosSettings count]);
        int settingResult = [printer setPrinterSettings:iosSettings];

        [printer endCommunication];

        NSString * errorName = [LegacyPrinterUtils errorNameForLegacyCode:settingResult];
        NSLog(@"[another_brother][updatePrinterSettings] setPrinterSettings: returned %d -> %@",
              settingResult, errorName);

        NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:errorName];

        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_result(status);
        });
    });
}

@end

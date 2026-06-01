//
//  GetPrinterSettingsMethodCall.m
//  another_brother
//
//  Mirrors the Android GetPrinterSettingsMethodCall behavior. Uses the legacy
//  BRPtouchPrinter API since BRLMPrinterDriver does not expose
//  getPrinterSettings:require:.
//

#import <Foundation/Foundation.h>
#import "GetPrinterSettingsMethodCall.h"
#import "LegacyPrinterUtils.h"

@implementation GetPrinterSettingsMethodCall
static NSString * METHOD_NAME = @"getPrinterSettings";

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
        NSArray * dartKeys = self->_call.arguments[@"keys"];

        NSLog(@"[another_brother][getPrinterSettings] Raw keys (count=%lu): %@",
              (unsigned long)[dartKeys count], dartKeys);

        // Build the require array expected by getPrinterSettings:require:.
        // Each element must be NSNumber wrapping the PrinterSettingItem raw
        // value (NSUInteger-typed - settingIdFromRawKey: normalizes that).
        NSMutableArray<NSNumber *> * requireKeys = [NSMutableArray arrayWithCapacity:[dartKeys count]];
        for (id rawKey in dartKeys) {
            NSNumber * settingId = [LegacyPrinterUtils settingIdFromRawKey:rawKey];
            if (settingId == nil) {
                NSLog(@"[another_brother][getPrinterSettings] Skipping unparseable key %@ (class=%@)",
                      rawKey, NSStringFromClass([rawKey class]));
                continue;
            }
            [requireKeys addObject:settingId];
        }

        NSMutableString * keyDiagnostic = [NSMutableString string];
        for (NSNumber * key in requireKeys) {
            const char * type = [key objCType];
            [keyDiagnostic appendFormat:@"%@(%s) ", key, type];
        }
        NSLog(@"[another_brother][getPrinterSettings] Built require array (count=%lu): %@",
              (unsigned long)[requireKeys count], keyDiagnostic);

        if ([requireKeys count] == 0) {
            NSLog(@"[another_brother][getPrinterSettings] No valid keys requested, returning ERROR_INVALID_PARAMETER without calling the SDK.");
            NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:@"ERROR_INVALID_PARAMETER"];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self->_result(@{
                    @"printerStatus": status,
                    @"values": @{}
                });
            });
            return;
        }

        BRPtouchPrinter * printer = [LegacyPrinterUtils brPtouchPrinterFromPrintInfoMap:dartPrintInfo];

        NSLog(@"[another_brother][getPrinterSettings] Calling startCommunication...");
        BOOL connOpened = [printer startCommunication];
        if (!connOpened) {
            NSLog(@"[another_brother][getPrinterSettings] startCommunication returned NO, aborting.");
            NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:@"ERROR_COMMUNICATION_ERROR"];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self->_result(@{
                    @"printerStatus": status,
                    @"values": @{}
                });
            });
            return;
        }

        NSLog(@"[another_brother][getPrinterSettings] Calling [BRPtouchPrinter getPrinterSettings:require:] with %lu keys...",
              (unsigned long)[requireKeys count]);
        // The Brother SDK header declares the out parameter as
        // (NSDictionary**), but some SDK versions require it to be
        // pre-allocated as a mutable dictionary the SDK fills in. Passing nil
        // can yield ERROR_INVALID_PARAMETER (-48). Hand it an empty mutable
        // dictionary instead. The __autoreleasing qualifier matches the ARC
        // convention for write-back parameters.
        NSDictionary * __autoreleasing sdkResult = [NSMutableDictionary dictionary];
        // Defensive copy of the require array in case the SDK is picky about
        // mutability of inputs.
        NSArray<NSNumber *> * requireImmutable = [requireKeys copy];
        int getResult = [printer getPrinterSettings:&sdkResult require:requireImmutable];

        [printer endCommunication];

        NSString * errorName = [LegacyPrinterUtils errorNameForLegacyCode:getResult];
        NSLog(@"[another_brother][getPrinterSettings] getPrinterSettings:require: returned %d -> %@, sdkResult=%@",
              getResult, errorName, sdkResult);

        // Translate the SDK dictionary (keys: NSNumber id, values: NSString)
        // into the Dart-side shape:
        //   { {"id": <int>, "name": <string>} : <string> }
        NSMutableDictionary * dartValues = [NSMutableDictionary dictionaryWithCapacity:[sdkResult count]];
        for (id rawKey in sdkResult) {
            NSNumber * settingId = [LegacyPrinterUtils settingIdFromRawKey:rawKey];
            id rawValue = [sdkResult objectForKey:rawKey];

            NSString * value = nil;
            if ([rawValue isKindOfClass:[NSString class]]) {
                value = (NSString *)rawValue;
            } else if ([rawValue isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)rawValue stringValue];
            } else if (rawValue != nil) {
                value = [rawValue description];
            } else {
                value = @"";
            }

            NSDictionary * dartKey = [LegacyPrinterUtils printerSettingItemMapForId:settingId];
            [dartValues setObject:value forKey:dartKey];
        }

        NSDictionary<NSString *, NSObject *> * status = [LegacyPrinterUtils printerStatusMapWithErrorName:errorName];

        NSLog(@"[another_brother][getPrinterSettings] Returning %lu values to dart.",
              (unsigned long)[dartValues count]);

        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_result(@{
                @"printerStatus": status,
                @"values": dartValues
            });
        });
    });
}

@end

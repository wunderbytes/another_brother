//
//  UpdatePrinterSettingsMethodCall.m
//  another_brother
//

#import <Foundation/Foundation.h>
#import "UpdatePrinterSettingsMethodCall.h"

@implementation UpdatePrinterSettingsMethodCall
static NSString * METHOD_NAME = @"updatePrinterSettings";
static NSString * LOG_TAG = @"[another_brother][iOS][updatePrinterSettings]";

- (instancetype)initWithCall:(FlutterMethodCall *)call
                      result:(FlutterResult) result {
    self = [super init];
    if (self) {
        _call = call;
        _result = result;
    }
    return self;
}

+ (NSString *) METHOD_NAME {
    return METHOD_NAME;
}

- (CONNECTION_TYPE)connectionTypeFromMap:(NSDictionary<NSString *, NSObject *> *)dartPrintInfo {
    NSDictionary<NSString *, NSObject *> *dartPort = (NSDictionary<NSString *, NSObject *> *)dartPrintInfo[@"port"];
    NSString *portName = (NSString *)dartPort[@"name"];

    if ([@"BLUETOOTH" isEqualToString:portName]) {
        return CONNECTION_TYPE_BLUETOOTH;
    }
    else if ([@"BLE" isEqualToString:portName]) {
        return CONNECTION_TYPE_BLE;
    }

    return CONNECTION_TYPE_WLAN;
}

- (BRPtouchPrinter *)createPrinterWithPrintInfo:(NSDictionary<NSString *, NSObject *> *)dartPrintInfo {
    NSDictionary<NSString *, NSObject *> *dartPrinterModel = (NSDictionary<NSString *, NSObject *> *)dartPrintInfo[@"printerModel"];
    NSString *printerModel = (NSString *)dartPrinterModel[@"name"];
    if (printerModel == nil || printerModel.length == 0) {
        return nil;
    }

    NSString *printerName = [printerModel stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    CONNECTION_TYPE connectionType = [self connectionTypeFromMap:dartPrintInfo];

    BRPtouchPrinter *printer = [[BRPtouchPrinter alloc] initWithPrinterName:printerName interface:connectionType];
    if (printer == nil) {
        return nil;
    }

    NSString *ipAddress = (NSString *)dartPrintInfo[@"ipAddress"];
    NSString *macAddress = (NSString *)dartPrintInfo[@"macAddress"];
    NSString *localName = (NSString *)dartPrintInfo[@"localName"];

    if (connectionType == CONNECTION_TYPE_BLUETOOTH && macAddress.length > 0) {
        [printer setupForBluetoothDeviceWithSerialNumber:macAddress];
    }
    else if (connectionType == CONNECTION_TYPE_BLE && localName.length > 0) {
        [printer setBLEAdvertiseLocalName:localName];
    }
    else if (ipAddress.length > 0) {
        [printer setIPAddress:ipAddress];
    }

    return printer;
}

- (NSDictionary<NSNumber *, NSString *> *)iosSettingsFromMap:(NSDictionary *)dartSettings {
    NSMutableDictionary<NSNumber *, NSString *> *printerSettings = [[NSMutableDictionary<NSNumber *, NSString *> alloc] init];

    if (![dartSettings isKindOfClass:[NSDictionary class]]) {
        return printerSettings;
    }

    [dartSettings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if (![value isKindOfClass:[NSString class]]) {
            return;
        }

        NSNumber *settingId = nil;
        if ([key isKindOfClass:[NSDictionary class]]) {
            NSDictionary *settingMap = (NSDictionary *)key;
            NSObject *idValue = settingMap[@"id"];
            if ([idValue isKindOfClass:[NSNumber class]]) {
                settingId = (NSNumber *)idValue;
            }
        }
        else if ([key isKindOfClass:[NSNumber class]]) {
            settingId = (NSNumber *)key;
        }
        else if ([key isKindOfClass:[NSString class]]) {
            NSInteger parsedId = [(NSString *)key integerValue];
            if (parsedId > 0) {
                settingId = @(parsedId);
            }
        }

        if (settingId != nil) {
            [printerSettings setObject:(NSString *)value forKey:settingId];
        }
    }];

    return printerSettings;
}

- (void)execute {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSString *printerId = self->_call.arguments[@"printerId"];
        NSDictionary<NSString *, NSObject *> *dartPrintInfo = self->_call.arguments[@"printInfo"];
        NSDictionary *dartSettings = self->_call.arguments[@"settings"];

        NSLog(@"%@ Request started (printerId=%@, settingsCount=%lu)",
              LOG_TAG, printerId ?: @"<none>", (unsigned long)[dartSettings count]);

        BRLMPrintErrorCode errorCode = BRLMPrintErrorCodeNoError;

        BRPtouchPrinter *printer = [self createPrinterWithPrintInfo:dartPrintInfo];
        NSDictionary<NSNumber *, NSString *> *printerSettings = [self iosSettingsFromMap:dartSettings];

        if (printer == nil) {
            NSLog(@"%@ Failed to create BRPtouchPrinter instance.", LOG_TAG);
            errorCode = BRLMPrintErrorCodePrinterStatusErrorCommunicationError;
        }
        else if (printerSettings.count == 0) {
            NSLog(@"%@ No valid settings were provided.", LOG_TAG);
            errorCode = BRLMPrintErrorCodePrintSettingsError;
        }
        else {
            BOOL started = [printer startCommunication];
            if (!started) {
                NSLog(@"%@ startCommunication failed.", LOG_TAG);
                errorCode = BRLMPrintErrorCodePrinterStatusErrorCommunicationError;
            }
            else {
                int updateSettingsResult = [printer setPrinterSettings:printerSettings];
                if (updateSettingsResult != RET_TRUE) {
                    NSLog(@"%@ setPrinterSettings failed (result=%d).", LOG_TAG, updateSettingsResult);
                    errorCode = BRLMPrintErrorCodePrintSettingsNotSupportError;
                }
                else {
                    NSLog(@"%@ setPrinterSettings succeeded (updated=%lu).",
                          LOG_TAG, (unsigned long)printerSettings.count);
                }
                [printer endCommunication];
            }
        }

        NSDictionary<NSString *, NSObject *> *printStatus = [BrotherUtils printerStatusToMapWithError:errorCode status:nil];
        NSLog(@"%@ Request finished (error=%@).",
              LOG_TAG, printStatus[@"errorCode"]);
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_result(printStatus);
        });
    });
}

@end

//
//  GetPrinterSettingsMethodCall.m
//  another_brother
//

#import <Foundation/Foundation.h>
#import "GetPrinterSettingsMethodCall.h"

@implementation GetPrinterSettingsMethodCall
static NSString * METHOD_NAME = @"getPrinterSettings";
static NSString * LOG_TAG = @"[another_brother][iOS][getPrinterSettings]";

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

- (NSArray<NSNumber *> *)iosSettingKeysFromArray:(NSArray *)dartKeys {
    NSMutableArray<NSNumber *> *keys = [[NSMutableArray<NSNumber *> alloc] init];

    if (![dartKeys isKindOfClass:[NSArray class]]) {
        return keys;
    }

    [dartKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSNumber *settingId = nil;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *settingMap = (NSDictionary *)obj;
            NSObject *idValue = settingMap[@"id"];
            if ([idValue isKindOfClass:[NSNumber class]]) {
                settingId = (NSNumber *)idValue;
            }
        }
        else if ([obj isKindOfClass:[NSNumber class]]) {
            settingId = (NSNumber *)obj;
        }

        if (settingId != nil) {
            [keys addObject:settingId];
        }
    }];

    return keys;
}

- (NSDictionary<NSNumber *, NSString *> *)settingNamesByIdFromArray:(NSArray *)dartKeys {
    NSMutableDictionary<NSNumber *, NSString *> *namesById = [[NSMutableDictionary<NSNumber *, NSString *> alloc] init];

    if (![dartKeys isKindOfClass:[NSArray class]]) {
        return namesById;
    }

    [dartKeys enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (![obj isKindOfClass:[NSDictionary class]]) {
            return;
        }

        NSDictionary *settingMap = (NSDictionary *)obj;
        NSObject *idValue = settingMap[@"id"];
        NSObject *nameValue = settingMap[@"name"];
        if ([idValue isKindOfClass:[NSNumber class]] && [nameValue isKindOfClass:[NSString class]]) {
            [namesById setObject:(NSString *)nameValue forKey:(NSNumber *)idValue];
        }
    }];

    return namesById;
}

- (NSDictionary<NSString *, NSObject *> *)printerStatusFromLegacyErrorCode:(int)errorCode {
    NSDictionary<NSString *, NSObject *> *dartError = [BrotherUtils errorCodeToMapWithId:[NSNumber numberWithInt:errorCode]];

    return @{
        @"errorCode": dartError,
        @"labelId": @(-1),
        @"labelType": @(-1),
        @"isACConnected": @{@"id": @(-1), @"name": @"Unknown"},
        @"isBatteryMounted": @{@"id": @(-1), @"name": @"Unknown"},
        @"batteryLevel": @(-1),
        @"batteryResidualQuantityLevel": @(-1),
        @"maxOfBatteryResidualQuantityLevel": @(-1),
    };
}

- (NSDictionary *)dartValuesFromPrinterSettings:(NSDictionary *)printerSettings namesById:(NSDictionary<NSNumber *, NSString *> *)namesById {
    NSMutableDictionary *dartValues = [[NSMutableDictionary alloc] init];

    if (![printerSettings isKindOfClass:[NSDictionary class]]) {
        return dartValues;
    }

    [printerSettings enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (![key isKindOfClass:[NSNumber class]] || ![obj isKindOfClass:[NSString class]]) {
            return;
        }

        NSDictionary *dartKey = @{
            @"id": (NSNumber *)key,
            @"name": namesById[(NSNumber *)key] ?: @"UNSUPPORTED"
        };
        [dartValues setObject:obj forKey:dartKey];
    }];

    return dartValues;
}

- (void)execute {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    dispatch_async(queue, ^{
        NSString *printerId = self->_call.arguments[@"printerId"];
        NSDictionary<NSString *, NSObject *> *dartPrintInfo = self->_call.arguments[@"printInfo"];
        NSArray *dartKeys = self->_call.arguments[@"keys"];

        NSLog(@"%@ Request started (printerId=%@, keysCount=%lu)",
              LOG_TAG, printerId ?: @"<none>", (unsigned long)[dartKeys count]);

        BRPtouchPrinter *printer = [self createPrinterWithPrintInfo:dartPrintInfo];
        NSArray<NSNumber *> *requireKeys = [self iosSettingKeysFromArray:dartKeys];
        NSDictionary<NSNumber *, NSString *> *settingNamesById = [self settingNamesByIdFromArray:dartKeys];

        int errorCode = ERROR_NONE_;
        NSDictionary *printerSettings = @{};

        if (printer == nil) {
            NSLog(@"%@ Failed to create BRPtouchPrinter instance.", LOG_TAG);
            errorCode = ERROR_COMMUNICATION_ERROR_;
        }
        else if (requireKeys.count == 0) {
            NSLog(@"%@ No valid keys were provided.", LOG_TAG);
            errorCode = ERROR_INVALID_PARAMETER_;
        }
        else {
            BOOL started = [printer startCommunication];
            if (!started) {
                NSLog(@"%@ startCommunication failed.", LOG_TAG);
                errorCode = ERROR_COMMUNICATION_ERROR_;
            }
            else {
                NSDictionary *outSettings = nil;
                errorCode = [printer getPrinterSettings:&outSettings require:requireKeys];
                if (errorCode == ERROR_NONE_) {
                    printerSettings = outSettings ?: @{};
                    NSLog(@"%@ getPrinterSettings succeeded (valuesCount=%lu).",
                          LOG_TAG, (unsigned long)printerSettings.count);
                }
                else {
                    NSLog(@"%@ getPrinterSettings failed (errorCode=%d).", LOG_TAG, errorCode);
                }
                [printer endCommunication];
            }
        }

        NSDictionary *result = @{
            @"printerStatus": [self printerStatusFromLegacyErrorCode:errorCode],
            @"values": [self dartValuesFromPrinterSettings:printerSettings namesById:settingNamesById]
        };

        NSLog(@"%@ Request finished (errorCode=%d).", LOG_TAG, errorCode);
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_result(result);
        });
    });
}

@end

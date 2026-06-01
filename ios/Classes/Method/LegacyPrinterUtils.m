//
//  LegacyPrinterUtils.m
//  another_brother
//

#import "LegacyPrinterUtils.h"
#import "BrotherUtils.h"

@implementation LegacyPrinterUtils

+ (NSString *)brotherPrinterNameFromDartModelName:(NSString *)dartModelName {
    if (dartModelName == nil) {
        return @"";
    }
    // Per Brother iOS SDK reference manual, BRPtouchPrinter expects the
    // printer name in the form e.g. @"QL-1110NWB" - no "Brother " prefix,
    // dashes instead of underscores.
    return [dartModelName stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
}

+ (BRPtouchPrinter *)brPtouchPrinterFromPrintInfoMap:(NSDictionary<NSString *, NSObject *> *)dartPrintInfo {
    NSDictionary<NSString *, NSObject*> * dartPort = (NSDictionary<NSString *, NSObject*> *)[dartPrintInfo objectForKey:@"port"];
    BRLMChannelType channelType = [BrotherUtils portFromMapWithValue:dartPort];

    NSString * ipAddress = (NSString *)[dartPrintInfo objectForKey:@"ipAddress"];
    NSString * macAddress = (NSString *)[dartPrintInfo objectForKey:@"macAddress"];
    NSString * localName = (NSString *)[dartPrintInfo objectForKey:@"localName"];

    NSDictionary<NSString *, NSObject*> * dartModel = (NSDictionary<NSString *, NSObject*> *)[dartPrintInfo objectForKey:@"printerModel"];
    NSString * dartModelName = (NSString *)[dartModel objectForKey:@"name"];
    NSString * brotherPrinterName = [LegacyPrinterUtils brotherPrinterNameFromDartModelName:dartModelName];

    CONNECTION_TYPE connectionType;
    if (channelType == BRLMChannelTypeWiFi) {
        connectionType = CONNECTION_TYPE_WLAN;
    } else if (channelType == BRLMChannelTypeBluetoothMFi) {
        connectionType = CONNECTION_TYPE_BLUETOOTH;
    } else if (channelType == BRLMChannelTypeBluetoothLowEnergy) {
        connectionType = CONNECTION_TYPE_BLE;
    } else {
        connectionType = CONNECTION_TYPE_WLAN;
    }

    BRPtouchPrinter * printer = [[BRPtouchPrinter alloc] initWithPrinterName:brotherPrinterName interface:connectionType];

    if (channelType == BRLMChannelTypeWiFi) {
        [printer setIPAddress:ipAddress];
    } else if (channelType == BRLMChannelTypeBluetoothMFi) {
        [printer setupForBluetoothDeviceWithSerialNumber:macAddress];
    } else if (channelType == BRLMChannelTypeBluetoothLowEnergy) {
        [printer setBLEAdvertiseLocalName:localName];
    }

    NSLog(@"[another_brother][legacy] BRPtouchPrinter ready | model='%@' interface=%lu ipAddress='%@' macAddress='%@' localName='%@'",
          brotherPrinterName, (unsigned long)connectionType, ipAddress, macAddress, localName);

    return printer;
}

+ (NSString *)errorNameForLegacyCode:(int)code {
    switch (code) {
        case ERROR_NONE_: return @"ERROR_NONE";
        case ERROR_TIMEOUT: return @"ERROR_EVALUATION_TIMEUP";
        case ERROR_BADPAPERRES: return @"ERROR_WRONG_LABEL";
        case ERROR_IMAGELARGE: return @"ERROR_SET_OVER_MARGIN";
        case ERROR_CREATESTREAM: return @"ERROR_CREATE_SOCKET_FAILED";
        case ERROR_OPENSTREAM: return @"ERROR_GET_OUTPUT_STREAM_FAILED";
        case ERROR_FILENOTEXIST: return @"ERROR_FILE_NOT_FOUND";
        case ERROR_PAGERANGEERROR: return @"ERROR_INVALID_PARAMETER";
        case ERROR_NOT_SAME_MODEL_: return @"ERROR_NOT_SAME_MODEL";
        case ERROR_BROTHER_PRINTER_NOT_FOUND_: return @"ERROR_BROTHER_PRINTER_NOT_FOUND";
        case ERROR_PAPER_EMPTY_: return @"ERROR_PAPER_EMPTY";
        case ERROR_BATTERY_EMPTY_: return @"ERROR_BATTERY_EMPTY";
        case ERROR_COMMUNICATION_ERROR_: return @"ERROR_COMMUNICATION_ERROR";
        case ERROR_OVERHEAT_: return @"ERROR_OVERHEAT";
        case ERROR_PAPER_JAM_: return @"ERROR_PAPER_JAM";
        case ERROR_HIGH_VOLTAGE_ADAPTER_: return @"ERROR_HIGH_VOLTAGE_ADAPTER";
        case ERROR_CHANGE_CASSETTE_: return @"ERROR_CHANGE_CASSETTE";
        case ERROR_FEED_OR_CASSETTE_EMPTY_: return @"ERROR_FEED_OR_CASSETTE_EMPTY";
        case ERROR_SYSTEM_ERROR_: return @"ERROR_SYSTEM_ERROR";
        case ERROR_NO_CASSETTE_: return @"ERROR_NO_CASSETTE";
        case ERROR_WRONG_CASSENDTE_DIRECT_: return @"ERROR_WRONG_CASSETTE_DIRECT";
        case ERROR_CREATE_SOCKET_FAILED_: return @"ERROR_CREATE_SOCKET_FAILED";
        case ERROR_CONNECT_SOCKET_FAILED_: return @"ERROR_CONNECT_SOCKET_FAILED";
        case ERROR_GET_OUTPUT_STREAM_FAILED_: return @"ERROR_GET_OUTPUT_STREAM_FAILED";
        case ERROR_GET_INPUT_STREAM_FAILED_: return @"ERROR_GET_INPUT_STREAM_FAILED";
        case ERROR_CLOSE_SOCKET_FAILED_: return @"ERROR_CLOSE_SOCKET_FAILED";
        case ERROR_OUT_OF_MEMORY_: return @"ERROR_OUT_OF_MEMORY";
        case ERROR_SET_OVER_MARGIN_: return @"ERROR_SET_OVER_MARGIN";
        case ERROR_NO_SD_CARD_: return @"ERROR_NO_SD_CARD";
        case ERROR_FILE_NOT_SUPPORTED_: return @"ERROR_FILE_NOT_SUPPORTED";
        case ERROR_EVALUATION_TIMEUP_: return @"ERROR_EVALUATION_TIMEUP";
        case ERROR_WRONG_CUSTOM_INFO_: return @"ERROR_WRONG_CUSTOM_INFO";
        case ERROR_NO_ADDRESS_: return @"ERROR_NO_ADDRESS";
        case ERROR_NOT_MATCH_ADDRESS_: return @"ERROR_NOT_MATCH_ADDRESS";
        case ERROR_FILE_NOT_FOUND_: return @"ERROR_FILE_NOT_FOUND";
        case ERROR_TEMPLATE_FILE_NOT_MATCH_MODEL_: return @"ERROR_TEMPLATE_FILE_NOT_MATCH_MODEL";
        case ERROR_TEMPLATE_NOT_TRANS_MODEL_: return @"ERROR_TEMPLATE_NOT_TRANS_MODEL";
        case ERROR_COVER_OPEN_: return @"ERROR_COVER_OPEN";
        case ERROR_WRONG_LABEL_: return @"ERROR_WRONG_LABEL";
        case ERROR_PORT_NOT_SUPPORTED_: return @"ERROR_PORT_NOT_SUPPORTED";
        case ERROR_WRONG_TEMPLATE_KEY_: return @"ERROR_WRONG_TEMPLATE_KEY";
        case ERROR_BUSY_: return @"ERROR_BUSY";
        case ERROR_TEMPLATE_NOT_PRINT_MODEL_: return @"ERROR_TEMPLATE_NOT_PRINT_MODEL";
        case ERROR_CANCEL_: return @"ERROR_CANCEL";
        case ERROR_PRINTER_SETTING_NOT_SUPPORTED_: return @"ERROR_PRINTER_SETTING_NOT_SUPPORTED";
        case ERROR_INVALID_PARAMETER_: return @"ERROR_INVALID_PARAMETER";
        case ERROR_INTERNAL_ERROR_: return @"ERROR_INTERNAL_ERROR";
        case ERROR_TEMPLATE_NOT_CONTROL_MODEL_: return @"ERROR_TEMPLATE_NOT_CONTROL_MODEL";
        case ERROR_TEMPLATE_NOT_EXIST_: return @"ERROR_TEMPLATE_NOT_EXIST";
        case ERROR_BUFFER_FULL_: return @"ERROR_BUFFER_FULL";
        case ERROR_TUBE_EMPTY_: return @"ERROR_TUBE_EMPTY";
        case ERROR_TUBE_RIBON_EMPTY_: return @"ERROR_TUBE_RIBBON_EMPTY";
        case ERROR_MINIMUM_LENGTH_LIMIT_: return @"ERROR_MINIMUM_LENGTH_LIMIT";
        default: return @"ERROR_INTERNAL_ERROR";
    }
}

+ (NSDictionary<NSString *, NSObject *> *)printerStatusMapWithErrorName:(NSString *)errorName {
    NSDictionary<NSString *, NSObject *> * dartError = @{
        @"name": errorName,
        @"id": [[NSNumber alloc] initWithInt:(-1)]
    };

    return @{
        @"errorCode": dartError,
        @"labelId": [[NSNumber alloc] initWithInt:(-1)],
        @"labelType": [[NSNumber alloc] initWithInt:(-1)],
        @"isACConnected": @{ @"id": [[NSNumber alloc] initWithInt:(-1)], @"name": @"Unknown" },
        @"isBatteryMounted": @{ @"id": [[NSNumber alloc] initWithInt:(-1)], @"name": @"Unknown" },
        @"batteryLevel": [[NSNumber alloc] initWithInt:(-1)],
        @"batteryResidualQuantityLevel": [[NSNumber alloc] initWithInt:(-1)],
        @"maxOfBatteryResidualQuantityLevel": [[NSNumber alloc] initWithInt:(-1)],
    };
}

+ (NSDictionary<NSString *, NSObject *> *)printerStatusMapForLegacyCode:(int)code {
    return [LegacyPrinterUtils printerStatusMapWithErrorName:[LegacyPrinterUtils errorNameForLegacyCode:code]];
}

+ (NSNumber *)settingIdFromRawKey:(id)rawKey {
    NSNumber * raw = nil;
    if ([rawKey isKindOfClass:[NSDictionary class]]) {
        id idValue = [(NSDictionary *)rawKey objectForKey:@"id"];
        if ([idValue isKindOfClass:[NSNumber class]]) {
            raw = (NSNumber *)idValue;
        } else if ([idValue isKindOfClass:[NSString class]]) {
            raw = @([(NSString *)idValue integerValue]);
        }
    } else if ([rawKey isKindOfClass:[NSNumber class]]) {
        raw = (NSNumber *)rawKey;
    } else if ([rawKey isKindOfClass:[NSString class]]) {
        raw = @([(NSString *)rawKey integerValue]);
    }

    if (raw == nil) {
        return nil;
    }

    // The Brother iOS SDK's PrinterSettingItem enum is declared as
    // NS_ENUM(NSUInteger, ...). Some legacy BRPtouchPrinter call sites validate
    // the objCType of the boxed number strictly, so we re-box every value as
    // an NSUInteger-typed NSNumber. The Flutter codec hands us int-typed
    // NSNumbers (objCType=='q'), which can be rejected as invalid parameters
    // by getPrinterSettings:require:.
    return [NSNumber numberWithUnsignedInteger:[raw unsignedIntegerValue]];
}

+ (NSDictionary<NSString *, NSObject *> *)printerSettingItemMapForId:(NSNumber *)settingId {
    static NSDictionary<NSNumber *, NSString *> * idToName = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        idToName = @{
            @1: @"NET_BOOTMODE",
            @2: @"NET_INTERFACE",
            @3: @"NET_USED_IPV6",
            @4: @"NET_PRIORITY_IPV6",
            @5: @"NET_IPV4_BOOTMETHOD",
            @6: @"NET_STATIC_IPV4ADDRESS",
            @7: @"NET_SUBNETMASK",
            @8: @"NET_GATEWAY",
            @9: @"NET_DNS_IPV4_BOOTMETHOD",
            @10: @"NET_PRIMARY_DNS_IPV4ADDRESS",
            @11: @"NET_SECOND_DNS_IPV4ADDRESS",
            @12: @"NET_IPV6_BOOTMETHOD",
            @13: @"NET_STATIC_IPV6ADDRESS",
            @14: @"NET_PRIMARY_DNS_IPV6ADDRESS",
            @15: @"NET_SECOND_DNS_IPV6ADDRESS",
            @16: @"NET_IPV6ADDRESS_LIST",
            @17: @"NET_COMMUNICATION_MODE",
            @18: @"NET_SSID",
            @19: @"NET_CHANNEL",
            @20: @"NET_AUTHENTICATION_METHOD",
            @21: @"NET_ENCRYPTIONMODE",
            @22: @"NET_WEPKEY",
            @23: @"NET_PASSPHRASE",
            @24: @"NET_USER_ID",
            @25: @"NET_PASSWORD",
            @26: @"NET_NODENAME",
            @27: @"WIRELESSDIRECT_KEY_CREATE_MODE",
            @28: @"WIRELESSDIRECT_SSID",
            @29: @"WIRELESSDIRECT_NETWORK_KEY",
            @30: @"BT_ISDISCOVERABLE",
            @31: @"BT_DEVICENAME",
            @34: @"BT_BOOTMODE",
            @35: @"PRINTER_POWEROFFTIME",
            @36: @"PRINTER_POWEROFFTIME_BATTERY",
            @37: @"PRINT_JPEG_HALFTONE",
            @38: @"PRINT_JPEG_SCALE",
            @39: @"PRINT_DENSITY",
            @40: @"PRINT_SPEED",
            @44: @"BT_AUTO_CONNECTION",
            @254: @"RESET",
            @255: @"UNSUPPORTED",
        };
    });

    NSString * name = settingId != nil ? [idToName objectForKey:settingId] : nil;
    if (name == nil) {
        return @{
            @"id": @255,
            @"name": @"UNSUPPORTED",
        };
    }
    return @{
        @"id": settingId,
        @"name": name,
    };
}

@end

//
//  UpdatePrinterSettingsMethodCall.m
//  another_brother
//

#import <Foundation/Foundation.h>
#import "UpdatePrinterSettingsMethodCall.h"

@implementation UpdatePrinterSettingsMethodCall
static NSString * METHOD_NAME = @"updatePrinterSettings";

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

- (void)execute {
    // Get printInfo dart params from call
    NSDictionary<NSString *, NSObject *> * dartPrintInfo = _call.arguments[@"printInfo"];
    // Settings is a map whose keys are PrinterSettingItem maps ({id, name}) and
    // whose values are the string values to apply, mirroring the Android side.
    NSDictionary * dartSettings = _call.arguments[@"settings"];

    FlutterResult result = _result;

    NSLog(@"[another_brother] updatePrinterSettings: requested with %lu setting(s)", (unsigned long)[dartSettings count]);

    // Communication with the printer is blocking so move it off the platform thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // Resolve the legacy BRPtouchPrinter model name (e.g. "QL-820NWB").
        NSDictionary<NSString *, NSObject *> * dartModel = (NSDictionary<NSString *, NSObject *> *)[dartPrintInfo objectForKey:@"printerModel"];
        NSString * modelName = (NSString *)[dartModel objectForKey:@"name"];
        modelName = [modelName stringByReplacingOccurrencesOfString:@"_" withString:@"-"];

        // Resolve the connection type and its identifier from the printInfo.
        NSDictionary<NSString *, NSObject *> * dartPort = (NSDictionary<NSString *, NSObject *> *)[dartPrintInfo objectForKey:@"port"];
        BRLMChannelType channelType = [BrotherUtils portFromMapWithValue:dartPort];

        NSString * ipAddress = (NSString *)[dartPrintInfo objectForKey:@"ipAddress"];
        NSString * macAddress = (NSString *)[dartPrintInfo objectForKey:@"macAddress"];
        NSString * localName = (NSString *)[dartPrintInfo objectForKey:@"localName"];

        CONNECTION_TYPE connectionType;
        if (channelType == BRLMChannelTypeBluetoothMFi) {
            connectionType = CONNECTION_TYPE_BLUETOOTH;
        } else if (channelType == BRLMChannelTypeBluetoothLowEnergy) {
            connectionType = CONNECTION_TYPE_BLE;
        } else {
            connectionType = CONNECTION_TYPE_WLAN;
        }

        // Create the printer and bind the identifier for the connection type.
        BRPtouchPrinter * printer = [[BRPtouchPrinter alloc] initWithPrinterName:modelName interface:connectionType];
        if (connectionType == CONNECTION_TYPE_BLUETOOTH) {
            [printer setupForBluetoothDeviceWithSerialNumber:macAddress];
        } else if (connectionType == CONNECTION_TYPE_BLE) {
            [printer setBLEAdvertiseLocalName:localName];
        } else {
            [printer setIPAddress:ipAddress];
        }

        NSLog(@"[another_brother] updatePrinterSettings: connecting to model '%@' over channel type %ld", modelName, (long)channelType);

        // Open the session before sending settings.
        BOOL started = [printer startCommunication];
        if (!started) {
            NSLog(@"[another_brother] updatePrinterSettings: failed to open communication with the printer");
            NSDictionary<NSString *, NSObject *> * printStatus = [BrotherUtils printerStatusToMapWithError:BRLMPrintErrorCodePrinterStatusErrorCommunicationError status:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                result(printStatus);
            });
            return;
        }

        // Build the settings dictionary expected by the SDK: keys are NSNumber of
        // PrinterSettingItem and values are NSString.
        NSMutableDictionary<NSNumber *, NSString *> * settings = [NSMutableDictionary dictionaryWithCapacity:[dartSettings count]];
        for (NSDictionary<NSString *, NSObject *> * keyMap in dartSettings) {
            NSNumber * settingItemId = (NSNumber *)[keyMap objectForKey:@"id"];
            NSString * settingValue = (NSString *)[dartSettings objectForKey:keyMap];
            if (settingItemId != nil && settingValue != nil) {
                [settings setObject:settingValue forKey:settingItemId];
            }
        }

        // Apply the settings.
        int settingsResult = [printer setPrinterSettings:settings];

        // Close the session.
        [printer endCommunication];

        NSLog(@"[another_brother] updatePrinterSettings: setPrinterSettings returned %d (RET_TRUE=%d)", settingsResult, RET_TRUE);

        // RET_TRUE on success, otherwise the change was rejected/unsupported.
        BRLMPrintErrorCode errorCode = (settingsResult == RET_TRUE)
            ? BRLMPrintErrorCodeNoError
            : BRLMPrintErrorCodePrintSettingsNotSupportError;

        NSDictionary<NSString *, NSObject *> * printStatus = [BrotherUtils printerStatusToMapWithError:errorCode status:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            result(printStatus);
        });
    });
}


@end

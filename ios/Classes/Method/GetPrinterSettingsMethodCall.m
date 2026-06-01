//
//  GetPrinterSettingsMethodCall.m
//  another_brother
//

#import <Foundation/Foundation.h>
#import "GetPrinterSettingsMethodCall.h"

@implementation GetPrinterSettingsMethodCall
static NSString * METHOD_NAME = @"getPrinterSettings";

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
    // The keys to retrieve. Each entry is a PrinterSettingItem map ({id, name}),
    // mirroring the Android side.
    NSArray<NSDictionary<NSString *, NSObject *> *> * dartKeys = _call.arguments[@"keys"];

    FlutterResult result = _result;

    NSLog(@"[another_brother] getPrinterSettings: requested %lu key(s)", (unsigned long)[dartKeys count]);

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

        NSLog(@"[another_brother] getPrinterSettings: connecting to model '%@' over channel type %ld", modelName, (long)channelType);

        // Open the session before retrieving settings.
        BOOL started = [printer startCommunication];
        if (!started) {
            NSLog(@"[another_brother] getPrinterSettings: failed to open communication with the printer");
            NSDictionary<NSString *, NSObject *> * printStatus = [BrotherUtils printerStatusToMapWithError:BRLMPrintErrorCodePrinterStatusErrorCommunicationError status:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                result(@{
                    @"printerStatus": printStatus,
                    @"values": @{}
                });
            });
            return;
        }

        // Build the require array expected by the SDK: NSNumber of PrinterSettingItem.
        NSMutableArray<NSNumber *> * require = [NSMutableArray arrayWithCapacity:[dartKeys count]];
        for (NSDictionary<NSString *, NSObject *> * keyMap in dartKeys) {
            NSNumber * settingItemId = (NSNumber *)[keyMap objectForKey:@"id"];
            if (settingItemId != nil) {
                [require addObject:settingItemId];
            }
        }

        // Retrieve the settings. The out dictionary keys are NSNumber of
        // PrinterSettingItem and the values are NSString.
        NSDictionary<NSNumber *, NSString *> * outSettings = nil;
        int settingsResult = [printer getPrinterSettings:&outSettings require:require];

        // Close the session.
        [printer endCommunication];

        NSLog(@"[another_brother] getPrinterSettings: getPrinterSettings returned %d with %lu value(s)", settingsResult, (unsigned long)[outSettings count]);

        // Translate the retrieved settings into the {id, name} -> value map the
        // Dart layer expects.
        NSMutableDictionary<NSDictionary<NSString *, NSObject *> *, NSString *> * dartValues = [NSMutableDictionary dictionaryWithCapacity:[outSettings count]];
        for (NSNumber * settingItemId in outSettings) {
            NSString * settingValue = [outSettings objectForKey:settingItemId];
            NSDictionary<NSString *, NSObject *> * keyMap = [BrotherUtils printerSettingItemToMapWithId:settingItemId];
            [dartValues setObject:settingValue forKey:keyMap];
        }

        // ERROR_NONE_ on success, otherwise treat as a communication failure.
        BRLMPrintErrorCode errorCode = (settingsResult == ERROR_NONE_)
            ? BRLMPrintErrorCodeNoError
            : BRLMPrintErrorCodePrinterStatusErrorCommunicationError;

        NSDictionary<NSString *, NSObject *> * printStatus = [BrotherUtils printerStatusToMapWithError:errorCode status:nil];

        dispatch_async(dispatch_get_main_queue(), ^{
            result(@{
                @"printerStatus": printStatus,
                @"values": dartValues
            });
        });
    });
}


@end

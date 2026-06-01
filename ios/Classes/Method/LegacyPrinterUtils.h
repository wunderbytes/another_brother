//
//  LegacyPrinterUtils.h
//  another_brother
//
//  Helpers shared between methods that use the legacy BRPtouchPrinter API
//  (currently updatePrinterSettings and getPrinterSettings). The newer
//  BRLMPrinterDriver API exposed in BrotherUtils does not provide
//  setPrinterSettings:/getPrinterSettings:require: so we have to drop down
//  to BRPtouchPrinter for those operations.
//

#ifndef LegacyPrinterUtils_h
#define LegacyPrinterUtils_h

#import <Foundation/Foundation.h>
#import <BRLMPrinterKit/BRPtouchPrinterKit.h>

@interface LegacyPrinterUtils : NSObject

// Converts a dart-side Model name (e.g. "QL_820NWB") to the printer name
// expected by BRPtouchPrinter init (e.g. "QL-820NWB"). The Brother iOS SDK
// reference manual uses names like @"QL-1110NWB" - i.e. no "Brother " prefix
// and dashes instead of underscores.
+ (NSString *)brotherPrinterNameFromDartModelName:(NSString *)dartModelName;

// Builds a BRPtouchPrinter instance configured for the connection target
// described by the dart printInfo map (port + ipAddress / macAddress /
// localName + printerModel). The returned printer still needs
// startCommunication to be called before any API that talks to the device.
+ (BRPtouchPrinter *)brPtouchPrinterFromPrintInfoMap:(NSDictionary<NSString *, NSObject *> *)dartPrintInfo;

// Maps a legacy BRPtouchPrinter integer error code (ERROR_NONE_, -3, -12, ...)
// to one of the dart-side ErrorCode names defined in printer_info.dart.
+ (NSString *)errorNameForLegacyCode:(int)code;

// Builds a Dart-side PrinterStatus map populated with just the error code,
// matching the shape produced by [BrotherUtils printerStatusToMapWithError:status:].
+ (NSDictionary<NSString *, NSObject *> *)printerStatusMapWithErrorName:(NSString *)errorName;

// Convenience: same as above but accepts the legacy int return code directly.
+ (NSDictionary<NSString *, NSObject *> *)printerStatusMapForLegacyCode:(int)code;

// Pulls the PrinterSettingItem id (1..44 / 254 / 255, matching the PSI_* enum
// values in BRPtouchPrinter.h and the dart-side PrinterSettingItem) out of
// whatever shape the Flutter codec produced for the settings-map key.
+ (NSNumber *)settingIdFromRawKey:(id)rawKey;

// Maps a PrinterSettingItem raw value back to the dart-side
// {"id": <int>, "name": <string>} dict so the dart layer can decode it via
// PrinterSettingItem.fromMap. Returns the UNSUPPORTED sentinel for unknown ids.
+ (NSDictionary<NSString *, NSObject *> *)printerSettingItemMapForId:(NSNumber *)settingId;

@end

#endif /* LegacyPrinterUtils_h */

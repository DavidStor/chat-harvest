#import "Decode.h"
#import <AppKit/AppKit.h>

NSString *DecodeMessageBody(NSData *data) {
    if (data.length == 0) return nil;
    @try {
        id value;
        if (data.length >= 6 && memcmp(data.bytes, "bplist", 6) == 0) {
            NSSet *classes = [NSSet setWithObjects:NSAttributedString.class,
                NSMutableAttributedString.class, NSString.class, NSMutableString.class,
                NSDictionary.class, NSMutableDictionary.class, NSArray.class,
                NSNumber.class, NSData.class, NSURL.class, NSColor.class, NSFont.class, nil];
            value = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:nil];
        } else {
            // Messages still stores NSArchiver typedstream bodies on modern macOS.
            // Keep Objective-C exceptions from damaged/unsupported archives out of Swift.
            value = [NSUnarchiver unarchiveObjectWithData:data];
        }
        if ([value isKindOfClass:NSAttributedString.class]) return [value string];
        if ([value isKindOfClass:NSString.class]) return value;
    } @catch (NSException *exception) { return nil; }
    return nil;
}

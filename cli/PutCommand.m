#import "PutCommand.h"
#import "util.h"
#import "../libhfs/hfs.h"

@implementation PutCommand

- (nonnull NSString *)name {
    return @"put";
}

- (nonnull NSString *)usage {
    return @"put local-path hfs-path type creator [--text]";
}

- (int)mountMode {
    return HFS_MODE_RDWR;
}

- (BOOL)executeOnVolume:(nonnull hfsvol *)vol withArgs:(nonnull NSArray<NSString *> *)args {
    BOOL textMode;
    
    if (args.count == 4) {
        textMode = NO;
    } else if (args.count == 5 && [args[4] isEqualToString:@"--text"]) {
        textMode = YES;
    } else {
        fprintf(stderr, "Usage: %s\n", [self.usage UTF8String]);
        return NO;
    }
    
    NSString *srcPath = args[0];
    NSString *destPath = qualify_path(args[1]);
    NSString *type = args[2];
    NSString *creator = args[3];

    return copy_in_data_fork(vol, srcPath, destPath, type, creator, textMode);
}

static BOOL copy_in_data_fork(hfsvol *vol, NSString *srcPath, NSString *destPath, NSString *type, NSString *creator, BOOL textMode) {
    NSError *error = nil;
    NSData *srcContents = [NSData dataWithContentsOfFile:srcPath options:0 error:&error];
    
    if (!srcContents) {
        fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
        return NO;
    }
    
    hfsfile *destFile = hfs_create(vol, [destPath cStringUsingEncoding:NSMacOSRomanStringEncoding], [type UTF8String], [creator UTF8String]);
    
    if (!destFile) {
        hfs_perror(destPath);
        return NO;
    }
    
    BOOL ok;

    if (textMode) {
        ok = copy_in_text(srcPath, srcContents, destPath, destFile);
    } else {
        ok = copy_in_raw(srcContents, destPath, destFile);
    }
    
    if (hfs_close(destFile) == -1) {
        perror([destPath UTF8String]);
        ok = NO;
    }
    
    return ok;
}

static BOOL copy_in_raw(NSData *srcContents, NSString *destPath, hfsfile *destFile) {
    if (hfs_write(destFile, srcContents.bytes, srcContents.length) == -1) {
        hfs_perror(destPath);
        return NO;
    }
    
    return YES;
}

static BOOL copy_in_text(NSString *srcPath, NSData *srcContents, NSString *destPath, hfsfile *destFile) {
    NSMutableString *srcStr = [[NSMutableString alloc] initWithData:srcContents encoding:NSUTF8StringEncoding];
    
    if (!srcStr) {
        fprintf(stderr, "%s: not valid UTF-8\n", [srcPath UTF8String]);
        return NO;
    }
    
    [srcStr replaceOccurrencesOfString:@"\n" withString:@"\r" options:NSLiteralSearch range:NSMakeRange(0, srcStr.length)];
    const char *converted = [srcStr cStringUsingEncoding:NSMacOSRomanStringEncoding];
    
    if (!converted) {
        fprintf(stderr, "%s: could not convert to Mac OS Roman\n", [srcPath UTF8String]);
        return NO;
    }
    
    if (hfs_write(destFile, converted, strlen(converted)) == -1) {
        hfs_perror(destPath);
        return NO;
    }
    
    return YES;
}



@end

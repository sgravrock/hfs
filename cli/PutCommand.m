#import "PutCommand.h"
#import <sys/xattr.h>
#import <errno.h>
#import "util.h"
#import "../libhfs/hfs.h"

@implementation PutCommand

- (nonnull NSString *)name {
    return @"put";
}

- (nonnull NSString *)usage {
    return @"put local-path hfs-path [--text | --type type:creator]";
}

- (int)mountMode {
    return HFS_MODE_RDWR;
}

- (BOOL)executeOnVolume:(nonnull hfsvol *)vol withArgs:(nonnull NSArray<NSString *> *)args {
    BOOL textMode;
    NSString *type = NULL;
    NSString *creator = NULL;
        
    if (args.count == 2) {
        textMode = NO;
    } else if (args.count == 3 && [args[2] isEqualToString:@"--text"]) {
        textMode = YES;
        type = @"TEXT";
        creator = @"ttxt"; // TeachText, usually the only available text editor
    } else if (args.count == 4 && [args[2] isEqualToString:@"--type"]) {
        if (args[3].length != 9 || [args[3] characterAtIndex:4] != ':') {
            fprintf(stderr, "Usage: %s\n", [self.usage UTF8String]);
            return NO;
        }
        
        textMode = NO;
        type = [args[3] substringToIndex:4];
        creator = [args[3] substringFromIndex:5];
    } else {
        fprintf(stderr, "Usage: %s\n", [self.usage UTF8String]);
        return NO;
    }
    
    NSString *srcPath = args[0];
    NSString *destPath = qualify_path(args[1]);
    
    return copy_in(vol, srcPath, destPath, type, creator, textMode);
}

static BOOL copy_in(hfsvol *vol, NSString *srcPath, NSString *destPath, NSString *type, NSString *creator, BOOL textMode) {
    if (type == NULL || creator == NULL) {
        infer_type_and_creator(srcPath, &type, &creator);
    }
    
    hfsfile *destFile = hfs_create(vol, [destPath cStringUsingEncoding:NSMacOSRomanStringEncoding], [type UTF8String], [creator UTF8String]);
    
    if (!destFile) {
        hfs_perror(destPath);
        return NO;
    }
    
    // TODO try to clean up dest file on failure (here and in GetCommand)
    
    if (!copy_in_data_fork(vol, srcPath, destPath, destFile, textMode)) {
        hfs_close(destFile);
        return NO;
    }
    
    NSString *srcResPath = osx_resource_fork_path(srcPath);
    FILE *srcResFp = fopen([srcResPath UTF8String], "rb");
    BOOL ok;
    
    if (!srcResFp) {
        if (errno == ENOENT) {
            ok = YES; // no resource fork
        } else {
            perror([srcResPath UTF8String]);
            ok = NO;
        }
    } else {
        ok = copy_in_resource_fork(vol, srcResPath, destPath, srcResFp, destFile);
        fclose(srcResFp);
    }
    
    if (hfs_close(destFile) == -1) {
        perror([destPath UTF8String]);
        ok = NO;
    }
    
    return ok;
}

static void infer_type_and_creator(NSString *srcPath, NSString **type, NSString **creator) {
    char attr[XATTR_FINDERINFO_LENGTH];
    bzero(attr, sizeof(attr));

    if (getxattr([srcPath UTF8String], XATTR_FINDERINFO_NAME, attr, 32, 0, 0) == -1) {
        if (errno != ENOATTR) {
            perror("getxattr");
        }
        
        fprintf(stderr, "%s: could not infer type and creator. Using ????.\n", [srcPath UTF8String]);
        *type = *creator = @"????";
        return;
    }
    
    char buf[5];
    bzero(buf, sizeof(buf));
    memcpy(buf, attr, 4);
    *type = [NSString stringWithUTF8String:buf];
    memcpy(buf, attr + 4, 4);
    *creator = [NSString stringWithUTF8String:buf];
    
    if (!type) {
        fprintf(stderr, "%s: found non-ASCII type. Using ????.\n", [srcPath UTF8String]);
        *type = @"????";
    }
    
    if (!creator) {
        fprintf(stderr, "%s: found non-ASCII creator. Using ????.\n", [srcPath UTF8String]);
        *creator = @"????";
    }
}

static BOOL copy_in_data_fork(hfsvol *vol, NSString *srcPath, NSString *destPath, hfsfile *destFile, BOOL textMode) {
    if (hfs_setfork(destFile, DATA_FORK) == -1) {
        hfs_perror(destPath);
        return NO;
    }

    NSError *error = nil;
    NSData *srcContents = [NSData dataWithContentsOfFile:srcPath options:0 error:&error];
    
    if (!srcContents) {
        fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
        return NO;
    }
        
    BOOL ok;

    if (textMode) {
        ok = copy_in_text(srcPath, srcContents, destPath, destFile);
    } else {
        ok = copy_in_raw(srcContents, destPath, destFile);
    }
        
    return ok;
}

static BOOL copy_in_resource_fork(hfsvol *vol, NSString *srcPath, NSString *destPath, FILE *srcFile, hfsfile *destFile) {
    if (hfs_setfork(destFile, RESOURCE_FORK) == -1) {
        hfs_perror(destPath);
        return NO;
    }

    NSError *error = nil;
    NSData *srcContents = [NSData dataWithContentsOfFile:srcPath options:0 error:&error];
    
    if (!srcContents) {
        fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
        return NO;
    }
    
    return copy_in_raw(srcContents, destPath, destFile);
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

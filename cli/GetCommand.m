#import "GetCommand.h"
#import "errors.h"
#import "../libhfs/hfs.h"

@implementation GetCommand

- (nonnull NSString *)name {
    return @"get";
}

- (nonnull NSString *)usage {
    return @"get hfs-path local-path [--text]";
}

- (int)mountMode {
    return HFS_MODE_RDONLY;
}

- (BOOL)executeOnVolume:(nonnull hfsvol *)vol withArgs:(nonnull NSArray<NSString *> *)args {
    NSString *srcPath, *destPath;
    BOOL textMode;
    
    if (args.count == 2) {
        textMode = NO;
    } else if (args.count == 3 && [args[2] isEqualToString:@"--text"]) {
        textMode = YES;
    } else {
        fprintf(stderr, "Usage: %s\n", [self.usage UTF8String]);
        return NO;
    }
    
    srcPath = args[0];
    destPath = args[1];
    
    // TODO: de-duplicate path handling with ls
    if ([srcPath characterAtIndex:0] != ':') {
        srcPath = [NSString stringWithFormat:@":%@", srcPath];
    }

    return copy_out_data_fork(vol, srcPath, destPath, textMode);
}

static BOOL copy_out_data_fork(hfsvol *vol, NSString *srcPath, NSString *destPath, BOOL textMode) {
    // TODO: Consider auto-detecting text files. Look at hfsutils's automode_hfs.
    hfsfile *srcFile = hfs_open(vol, [srcPath cStringUsingEncoding:NSMacOSRomanStringEncoding]);
    
    if (!srcFile) {
        hfs_perror([srcPath UTF8String]);
        return NO;   
    }
    
    FILE *destFile = fopen([destPath UTF8String], "wxb");
    
    if (!destFile) {
        perror([[NSString stringWithFormat:@"Open %@", destPath] UTF8String]);
        hfs_close(srcFile);
        return NO;
    }
    
    BOOL ok;
    
    if (textMode) {
        ok = copy_out_text(srcPath, destPath, srcFile, destFile);
    } else {
        ok = copy_out_raw(srcPath, destPath, srcFile, destFile);
    }
    
    if (fclose(destFile) != 0) {
        perror([[NSString stringWithFormat:@"Close %@", destPath] UTF8String]);
        ok = NO;
    }
    
    hfs_close(srcFile);
    return ok;
}

static BOOL copy_out_raw(NSString *srcPath, NSString *destPath, hfsfile *srcFile, FILE *destFile) {
    char buf[HFS_BLOCKSZ];
    long chunklen;

    do {
        chunklen = hfs_read(srcFile, buf, sizeof(buf));
        
        if (chunklen < 0) {
            hfs_perror([srcPath UTF8String]);
            return NO;
        } else if (chunklen > 0) {
            if (fwrite(buf, chunklen, 1, destFile) != 1) {
                perror([[NSString stringWithFormat:@"Write %@", destPath] UTF8String]);
                return NO;
            }
        }
    } while (chunklen > 0);

    return YES;
}

static BOOL copy_out_text(NSString *srcPath, NSString *destPath, hfsfile *srcFile, FILE *destFile) {
    char buf[HFS_BLOCKSZ + 1];
    long chunklen;

    do {
        chunklen = hfs_read(srcFile, buf, sizeof(buf) - 1);
        
        if (chunklen < 0) {
            hfs_perror([srcPath UTF8String]);
            return NO;
        } else if (chunklen > 0) {
            for (long i = 0; i < chunklen; i++) {
                if (buf[i] == '\r') {
                    buf[i] = '\n';
                }
            }

            buf[chunklen] = '\0';
            const char *converted = [[[NSString alloc] initWithCString:buf encoding:NSMacOSRomanStringEncoding] UTF8String];
            
            if (fwrite(converted, strlen(converted), 1, destFile) != 1) {
                perror([[NSString stringWithFormat:@"Write %@", destPath] UTF8String]);
                return NO;
            }
        }
    } while (chunklen > 0);

    return YES;
}


@end

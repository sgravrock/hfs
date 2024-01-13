#import "LsCommand.h"
#import "util.h"

static BOOL ls(hfsvol *vol, NSString *dir_path);

@implementation LsCommand

- (nonnull NSString *)name {
    return @"ls";
}

- (NSString *)usage {
    return @"ls [HFS path]";
}

- (int)mountMode {
    return HFS_MODE_RDONLY;
}

- (BOOL)executeOnVolume:(hfsvol *)vol withArgs:(NSArray<NSString *> *)args {
    if (args.count > 1) {
        fprintf(stderr, "Usage: %s\n", [self.usage UTF8String]);
        return NO;
    }
    
    NSString *path = qualify_path(args.count == 0 ? @":" : args[0]);
    return ls(vol, path);
}

static BOOL ls(hfsvol *vol, NSString *dir_path) {
    hfsdirent dirent;

    hfsdir *dir = hfs_opendir(vol, [dir_path cStringUsingEncoding:NSMacOSRomanStringEncoding]);

    if (!dir) {
        hfs_perror(dir_path);
        return NO;
    }

    while (hfs_readdir(dir, &dirent) == 0) {
        NSString *name = [NSString stringWithCString:dirent.name encoding:NSMacOSRomanStringEncoding];

        if ([name canBeConvertedToEncoding:NSUTF8StringEncoding]) {
            printf("%s ", [name UTF8String]);
        } else {
            fputs("(don't know how to print this name) ", stdout);
        }
        
        if (dirent.flags & HFS_ISDIR) {
            puts("(dir)\n");
        } else {
            printf("(type=%s creator=%s)\n", dirent.u.file.type, dirent.u.file.creator);
        }
    }

    // hfs_readdir sets errno to ENOENT at end of dir.
    // Anything else is an actual error.
    if (errno != ENOENT) {
        hfs_perror(dir_path ? dir_path : @"root");
        return NO;
    }

    hfs_closedir(dir);
    return YES;
}


@end

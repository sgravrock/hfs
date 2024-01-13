#import "LsCommand.h"
#import "errors.h"

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
    
    // libhfs expects the following path formats:
    // * "" refers to a virtual root directory containing all mounted volumes
    //   (not relevant here)
    // * ":" refers to the root of the volume
    // * All other paths starting with ":" are cwd-relative
    // * If a path contains colons but does not start with one, the first element
    //   is a volume name
    // * Paths not containing any colons are interpreted as immediate children of the
    //   root dir
    //
    // Except for the last point, this is consistent with how Macintosh users would
    // have understood paths in the pre-OSX days (to the extent that they thought
    // about paths at all). However, it's ill suited to our purposes because there
    // is only one volume, the user may not know the volume name, and there is no
    // concept of a cwd.
    //
    // To make things more convenient, we assume that all paths are relative to the
    // volume root regardless of whether or not they start with a colon.

    NSString *path = args.count == 0 ? @":" : args[0];
    
    if ([path characterAtIndex:0] != ':') {
        path = [NSString stringWithFormat:@":%@", path];
    }
    
    return ls(vol, path);
}

static BOOL ls(hfsvol *vol, NSString *dir_path) {
    hfsdirent dirent;

    hfsdir *dir = hfs_opendir(vol, [dir_path cStringUsingEncoding:NSMacOSRomanStringEncoding]);

    if (!dir) {
        hfs_perror([dir_path UTF8String]);
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
        hfs_perror(dir_path ? [dir_path UTF8String] : "root");
        return NO;
    }

    hfs_closedir(dir);
    return YES;
}


@end

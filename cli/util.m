#import "util.h"
#import "../libhfs/hfs.h"

void hfs_perror(NSString *prefix) {
    if (hfs_error) {
        fprintf(stderr, "%s: %s\n", [prefix UTF8String], hfs_error);
    } else {
        perror([prefix UTF8String]);
    }
}

NSString *qualify_path(NSString *path) {
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

    if ([path characterAtIndex:0] != ':') {
        path = [NSString stringWithFormat:@":%@", path];
    }
    
    return path;
}

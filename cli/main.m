//
//  main.m
//  hfs
//
//  Created by Stephen Gravrock on 1/7/24.
//

#import <Foundation/Foundation.h>
#import "../libhfs/hfs.h"

static void usage(const char *progname);
static void hfs_perror(const char *prefix);
static hfsvol *mount_first_partition(const char *path, int hfs_mode);
static BOOL ls(hfsvol *vol, NSString *dir_path);

int main(int argc, const char * argv[]) {
    BOOL ok = YES;
    
    @autoreleasepool {
        if (argc < 2) {
            usage(argv[0]);
        }
        
        const char *path = argv[1];
        int partitionNum = -1;
        
        if (argc > 2) {
            char *endp;
            unsigned long tmp = strtoul(argv[2], &endp, 10);
            
            if (*endp != '\0' || tmp > INT_MAX) {
                usage(argv[0]);
            }
            
            partitionNum = (int)tmp;
        }
        
        hfsvol *vol = partitionNum == -1
            ? mount_first_partition(path, HFS_MODE_RDONLY)
            : hfs_mount(path, partitionNum, HFS_MODE_RDONLY);
        
        if (!vol) {
            hfs_perror(path);
            return EXIT_FAILURE;
        }

        ok = ls(vol, @":");
        hfs_umount(vol);
    }

    return ok ? 0 : EXIT_FAILURE;
}

static void usage(const char *progname) {
    fprintf(stderr, "Usage: %s image-filename [partition-number]\n", progname);
    exit(EXIT_FAILURE);
}

static void hfs_perror(const char *prefix) {
    if (hfs_error) {
        fprintf(stderr, "%s: %s\n", prefix, hfs_error);
    } else {
        perror(prefix);
    }
}

static hfsvol *mount_first_partition(const char *path, int hfs_mode) {
    // Old Mac hard disk images can have an arbitrarily large number of partitions,
    // but in practice high numbers are rare and the vast majority of media will be
    // either floppy images (no partition table, libhfs models this as partition 0)
    // or hard disk iamges that only have partition 1.
    // If we haven't found anything by partition 1, it's likely that this isn't a
    // valid disk image.
    int maxpn = 10;
    
    for (int pn = 0; pn <= maxpn; pn++) {
        hfsvol *result = hfs_mount(path, pn, hfs_mode);
        
        if (result) {
            return result;
        }
    }
    
    fprintf(stderr, "Could not find a partition in %s. Either this isn't a useable disk image or the partition number is greater than 10. Try specifiying the partition number.\n", path);
    exit(EXIT_FAILURE);
}

static BOOL ls(hfsvol *vol, NSString *dir_path) {
    BOOL ok = YES;
    hfsdirent dirent;
    
    hfsdir *dir = hfs_opendir(vol, [dir_path cStringUsingEncoding:NSMacOSRomanStringEncoding]);
    
    if (!dir) {
        hfs_perror([dir_path UTF8String]);
        return NO;
    }
    
    while (hfs_readdir(dir, &dirent) == 0) {
        NSString *path;
        NSString *name = [NSString stringWithCString:dirent.name encoding:NSMacOSRomanStringEncoding];

        // libhfs expects the following path formats:
        // * "" refers to a virtual root directory containing all mounted volumes
        //   (not relevant here)
        // * ":" refers to the root of the volume
        // * All other paths starting with ":" are cwd-relative
        // * Paths not containing any colons are interpreted as immediate children of the
        //   root dir
        // There does not appear to be any general support for absolute paths within the
        // current volume, but since we never set the volume's cwd, we can use the
        // relative syntax (":foo:bar") as if it was absolute.
        if ([dir_path isEqualToString:@":"]) {
            path = [NSString stringWithFormat:@":%@", name];
        } else {
            path = [NSString stringWithFormat:@"%@:%@", dir_path, name];
        }
        
        if ([path canBeConvertedToEncoding:NSUTF8StringEncoding]) {
            printf("%s (%s)\n", [path UTF8String], dirent.flags & HFS_ISDIR ? "dir" : "file");
        } else {
            printf("(don't know how to print this) (%s)\n", dirent.flags & HFS_ISDIR ? "dir" : "file");
        }
        
        if (dirent.flags & HFS_ISDIR) {
            ls(vol, path);
        }
    }
    
    if (errno != ENOENT) {
        hfs_perror(dir_path ? [dir_path UTF8String] : "root");
        ok = NO;
    }
    
    hfs_closedir(dir);
    return ok;
}

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
static BOOL ls(hfsvol *vol, NSString *dir_path);

int main(int argc, const char * argv[]) {
    BOOL ok = YES;
    
    @autoreleasepool {
        if (argc < 2) {
            usage(argv[0]);
        }
        
        const char *path = argv[1];
        int partitionNum = 0;
        
        if (argc > 2) {
            char *endp;
            unsigned long tmp = strtoul(argv[2], &endp, 10);
            
            if (*endp != '\0' || tmp > INT_MAX) {
                usage(argv[0]);
            }
            
            partitionNum = (int)tmp;
        }
        
        hfsvol *vol = hfs_mount(path, partitionNum, HFS_MODE_RDONLY);
        
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

        if ([dir_path isEqualToString:@":"]) {
            path = name;
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

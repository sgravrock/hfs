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
static void inner_cli(hfsvol *vol);
static void inner_usage(void);
static NSString *readline(void);
static void ls(hfsvol *vol, NSString *dir_path);

int main(int argc, const char * argv[]) {
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
        
        hfsvol *vol;
        
        if (partitionNum == -1) {
            vol = mount_first_partition(path, HFS_MODE_RDONLY); // exits on failure
        } else {
            vol = hfs_mount(path, partitionNum, HFS_MODE_RDONLY);
            
            if (!vol) {
                hfs_perror(path);
                return EXIT_FAILURE;
            }
        }

        inner_cli(vol);
        hfs_umount(vol);
    }

    return 0;
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

static void inner_cli(hfsvol *vol) {
    NSString *cmd;
    printf("> ");
    fflush(stdout);
    
    while ((cmd = readline()) != NULL) {
        if ([cmd isEqualToString:@"ls"]) {
            ls(vol, @":");
        } else if ([cmd hasPrefix:@"ls "] && cmd.length > 3) {
            NSString *path = [cmd substringFromIndex: 3];
            ls(vol, path);
        } else {
            inner_usage();
        }
        
        printf("> ");
        fflush(stdout);
    }
}

static void inner_usage(void) {
    puts("Commands:");
    puts("ls                   list the root directory");
    puts("ls :dir1:dir2:dir3   list a specific directory");
    puts("help                 show this help");
    puts("");
    puts("ctrl-d to exit");
}

static NSString *readline(void) {
    // Just use a big buffer and bail if the command doesn't fit.
    // This is easier than trying to deal with scenarios where e.g a Unicode character
    // is split between two reads, and the internal CLI is temporary anyway.
    const int bufsz = 1024; // fairly arbitrary
    char buf[bufsz];
    
    if (!fgets(buf, bufsz, stdin)) {
        return nil;
    }
    
    char *nl = strchr(buf, '\n');
    
    if (!nl) {
        fprintf(stderr, "Command too long\n");
        exit(EXIT_FAILURE);
    }
    
    *nl = '\0';
    return [NSString stringWithUTF8String:buf];
}

static void ls(hfsvol *vol, NSString *dir_path) {
    hfsdirent dirent;

    hfsdir *dir = hfs_opendir(vol, [dir_path cStringUsingEncoding:NSMacOSRomanStringEncoding]);

    if (!dir) {
        hfs_perror([dir_path UTF8String]);
        return;
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
    }

    if (errno != ENOENT) {
        hfs_perror(dir_path ? [dir_path UTF8String] : "root");
    }

    hfs_closedir(dir);
}

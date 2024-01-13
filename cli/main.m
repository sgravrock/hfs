#import <Foundation/Foundation.h>
#import "errors.h"
#import "LsCommand.h"
#import "../libhfs/hfs.h"

static void usage(const char *progname, NSArray<id<Command>> *cmds);
static id<Command> first_matching_cmd(NSArray<id<Command>> *cmds, NSString *name);
static NSArray<NSString *> *array_from_argv(const char **argv);
static hfsvol *mount_first_partition(const char *path, int hfs_mode);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSArray<id<Command>> *cmds = @[[[LsCommand alloc] init]];
        const char *path = argv[1];
        id<Command> cmd = first_matching_cmd(cmds, [NSString stringWithUTF8String:argv[2]]);
        
        if (!cmd) {
            usage(argv[0], cmds);
            printf("no cmd\n");
            return EXIT_FAILURE;
        }
                
        hfsvol *vol = mount_first_partition(path, HFS_MODE_RDONLY);
        
        if (!vol) {
            return EXIT_FAILURE;
        }
        
        BOOL ok = [cmd executeOnVolume:vol withArgs:array_from_argv(argv + 3)];
        
        hfs_umount(vol);
        return ok ? 0 : EXIT_FAILURE;
    }
}

static void usage(const char *progname, NSArray<id<Command>> *cmds) {
    fprintf(stderr, "Usage: %s image-filename [partition-number] command [args...]\n\n", progname);
    fprintf(stderr, "Commands:\n");
    
    for (id<Command> cmd in cmds) {
        fprintf(stderr, "%s\n", [[cmd usage] UTF8String]);
    }
    
    exit(EXIT_FAILURE);
}

static id<Command> first_matching_cmd(NSArray<id<Command>> *cmds, NSString *name) {
    for (id<Command> cmd in cmds) {
        if ([cmd.name isEqualToString:name]) {
            return cmd;
        }
    }
    
    return nil;
}

static NSArray<NSString *> *array_from_argv(const char **argv) {
    NSMutableArray *result = [NSMutableArray array];
    
    while (*argv) {
        [result addObject:[NSString stringWithUTF8String:*argv]];
        argv++;
    }
    
    return result;
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
    
    fprintf(stderr, "Could not find a partition in %s. Either this isn't a useable disk image or the partition number is too high\n", path);
    return NULL;
}

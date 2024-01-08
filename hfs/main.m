//
//  main.m
//  hfs
//
//  Created by Stephen Gravrock on 1/7/24.
//

#import <Foundation/Foundation.h>
#import "../libhfs/hfs.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "Usage: %s image-filename\n", argv[0]);
            return EXIT_FAILURE;
        }
        
        const char *path = argv[1];
        
        // Assume partition 0 for now
        hfsvol *vol = hfs_mount(path, 0, HFS_MODE_RDONLY);
        
        if (!vol) {
            if (hfs_error) {
                fprintf(stderr, "%s: %s\n", path, hfs_error);
            } else {
                perror(path);
            }

            return EXIT_FAILURE;
        }
        
        hfs_umount(vol);
        printf("%s is a mountable HFS image\n", path);
    }

    return 0;
}

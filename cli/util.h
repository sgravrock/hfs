#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define DATA_FORK 0
#define RESOURCE_FORK 1
#define XATTR_FINDERINFO_LENGTH 32 // see ATTR_CMN_FNDRINFO in getattrlist(2)

void hfs_perror(NSString *prefix);
NSString *qualify_path(NSString *path);
NSString *osx_resource_fork_path(NSString *filePath);



NS_ASSUME_NONNULL_END

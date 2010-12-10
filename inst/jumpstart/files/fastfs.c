/* 
 * $Id: fastfs.c,v 1.3 1995/02/02 15:32:19 casper Exp casper $
 *
 * This programs turns on/off delayed I/O on a filesystem.
 * 
 * Usage:   fastfs filesystem fast|slow|status
 *
 * Note that it is intended for use with restore(8)
 * to speed up full filesystem restores. Remember
 * that if a filesystem is running with delayed I/O
 * enabled when the system crashes it can result in
 * fsck being unable to "fix" the filesystem on reboot
 * without manual intervention.
 *
 * Typical use is
 *
 * fastfs /home fast
 * cd /home; restore rf /dev/rst5
 * fastfs /home slow
 *
 * The above gives about a 500% increase in the speed of
 * the restore (your milage may vary).
 *
 * Its also good for /tmp giving most of the benifits of tmpfs
 * without the problems.
 *
 * In rc.local
 *
 * fastfs /tmp fast
 *
 * but you may need to add fsck -y /tmp into /etc/rc.boot
 * before the real fsck to ensure the machine always boots
 *
 * Adapted from the original fastfs.c code by
 * Peter Gray,  University of Wollongong.
 *
 * Casper Dik
*/

#include <stdio.h> 
#include <string.h> 
#include <sys/ioctl.h>
#include <sys/filio.h>
#include <fcntl.h>
#include <errno.h>
#ifndef FIODIO
#define SOLARIS
#define FIODIO _FIOSDIO
#define FIODIOS _FIOGDIO
#include <sys/mnttab.h>
#define MTAB "/etc/mnttab"
#else
#include <mntent.h>
#define MTAB "/etc/mtab"
#endif

#ifndef SOLARIS
extern char *sys_errlist[];
extern int sys_nerr;
#define strerror(x) ((x > sys_nerr || x < 0) ? "Uknown error" : sys_errlist[x])
#endif

int errors;

char *cmds[] = {  "slow", "fast", "status" };

#define CMD_SLOW 0
#define CMD_FAST 1
#define CMD_STATUS 2
#define CMD_ERROR -1
#define CMD_AMBIGUOUS -2

int
str2cmd(str)
char *str;
{
    int i,len = strlen(str), hits = 0, res = CMD_ERROR;
    for (i = 0; i < sizeof(cmds)/sizeof(char*); i++) {
        if (strncmp(str, cmds[i], len) == 0) {
            res = i;
            hits++;
        }
    }
    if (hits <= 1)
        return res;
    else
        return CMD_AMBIGUOUS;
}

void
fastfs(path, cmd)
char *path;
int cmd;
{
    int fd = open(path, O_RDONLY);
    int flag, newflag, oldflag, nochange = 0;
    char *how;

    if (fd < 0) {
        perror(path);
        errors ++;
        return;
    }
    if (ioctl(fd, FIODIOS, &oldflag) == -1) {
        perror("status ioctl");
        errors ++;
        return;
    }
    switch (cmd) {
        case CMD_SLOW:
            flag = 0;
            if (oldflag == flag)
                nochange = 1;
            else
                if (ioctl(fd, FIODIO, &flag) == -1) {
                    perror("slow ioctl");
                    errors ++;
                    return;
                }
            break;
        case CMD_FAST:
            flag = 1;
            if (oldflag == flag)
                nochange = 1;
            else
                if (ioctl(fd, FIODIO, &flag) == -1) {
                    perror("fast ioctl");
                    errors ++;
                    return;
                }
            break;
        case CMD_STATUS:
            how = "";
            break;
        default:
            fprintf(stderr,"Internal error: unexpected command\n");
            exit(1);
            /*NOTREACHED*/
    }
    if (ioctl(fd, FIODIOS, &newflag) == -1) {
        perror("status ioctl");
        errors ++;
    } else {
        if (cmd != CMD_STATUS && flag != newflag)
            printf("FAILED: ");
        if (cmd != CMD_STATUS)
            how = nochange ? "already " : "now ";
        printf("%s\tis %s%s\n", path, how, cmds[newflag]);
    }
    close(fd);
}

void usage()
{
    fprintf(stderr,"Usage: fastfs -a [slow|status|fast]\n");
    fprintf(stderr,"Usage: fastfs path1 .. pathN [slow|status|fast]\n");
    exit(1);
}

int
main(argc, argv)
int argc;
char    **argv;
{
    int opstat = 0;
    int i;
    char *cmd;
    int icmd;
    
    /*
     * New usage:
     * fastfs -a  [ report status on all ufs filesystems ]
     * fastfs -a status|slow|fast
     * fastfs path1 ... pathN status|slow|fast
     */

    if (argc < 2) usage();

    if (argc > 2) {
        if (str2cmd(argv[argc-1]) == CMD_ERROR)
            opstat = 1;
    } else
        opstat = 1;

    if (opstat)
        cmd = "status";
    else
        cmd = argv[argc-1];

    if ((icmd = str2cmd(cmd)) < 0)
        usage();

    if (strcmp(argv[1],"-a") == 0) {
        FILE *fp = fopen(MTAB,"r");
#ifdef SOLARIS
        struct mnttab mp, mtemplate;
#else
        struct mntent *mnt;
#endif

        if (fp == NULL) {
            fprintf(stderr,"Can't open %s\n", MTAB);
            exit(1);
        }
        if (argc + opstat != 3)
            usage();
#ifdef SOLARIS
        mtemplate.mnt_fstype = "ufs";
        mtemplate.mnt_special = 0;
        mtemplate.mnt_mntopts = 0;
        mtemplate.mnt_mountp = 0;
        mtemplate.mnt_time = 0;
        while (getmntany(fp, &mp, &mtemplate) == 0)
            fastfs(mp.mnt_mountp, icmd);
#else
        while (mnt = getmntent(fp)) {
            if (strcmp(mnt->mnt_type,"4.2") != 0)
                continue;
            fastfs(mnt->mnt_dir, icmd);
        }
#endif
        fclose(fp);
    } else {
        for (i = 1; i < argc + opstat - 1; i++)
            fastfs(argv[i], icmd);
    }

    exit(errors ? 1 : 0);
}


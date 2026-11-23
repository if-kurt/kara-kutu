/* Kara Kutu G23: reboot(LINUX_REBOOT_CMD_RESTART2, "<arg>"). busybox reboot argüman geçemiyor.
 * Kullanım: kk-reboot2 bootloader   (yalnız bu argümana izin verir)
 * Önce sync(). Dönerse (reboot başarısız) 1 ile çıkar; çağıran init bunu ele alır. */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/reboot.h>

int main(int argc, char **argv)
{
	if (argc != 2 || strcmp(argv[1], "bootloader") != 0) {
		fprintf(stderr, "kullanim: kk-reboot2 bootloader\n");
		return 2;
	}
	sync();
	syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		LINUX_REBOOT_CMD_RESTART2, argv[1]);
	perror("kk-reboot2: reboot");
	return 1;
}

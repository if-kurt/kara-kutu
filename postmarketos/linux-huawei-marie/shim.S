/*
 * DTB shim for the Huawei P30 Lite (Kirin 710), arm64.
 *
 * The stock bootloader unpacks the payload of the "kernel" partition to
 * 0x00080000 and jumps there with x0 = ITS OWN device tree. It ignores the
 * DTB inside the boot image. The partitions that hold that device tree must
 * never be written, so this shim:
 *   1) copies the embedded mainline Image to KERNEL_DEST (2 MiB aligned;
 *      kernels since 5.8 want a 2 MiB aligned base, not 0x80000),
 *   2) invalidates the instruction cache,
 *   3) jumps to the Image with x0 = embedded DTB and x1 = x2 = x3 = 0.
 *
 * Layout: [shim + header] [DTB, 8 byte aligned] [Image, 4 KiB aligned]
 * Entered with MMU and D-cache off (arm64 boot protocol), so the copy goes
 * straight to memory.
 *
 * Not implemented: handing an initramfs to the kernel (see README, "Initramfs").
 */
#ifndef KERNEL_DEST
#define KERNEL_DEST 0x04000000
#endif
	.section .text
	.global _start
_start:
	/* 64 byte arm64 Image header, kept valid so tools can inspect the blob */
	b	real_start		/* code0 */
	.long	0			/* code1 */
	.quad	0x80000			/* text_offset */
	.quad	blob_end - _start	/* image_size */
	.quad	0x2			/* flags: little endian, 4K pages */
	.quad	0
	.quad	0
	.quad	0
	.ascii	"ARM\x64"		/* magic */
	.long	0			/* res5 */

real_start:
	adrp	x4, kernel_start	/* position independent, +-4 GiB */
	add	x4, x4, :lo12:kernel_start
	adrp	x5, kernel_end
	add	x5, x5, :lo12:kernel_end
	ldr	x6, =KERNEL_DEST
	mov	x7, x6
	/* overlap check: stop if the destination starts before the source ends */
	cmp	x6, x5
	b.lo	hang
1:	cmp	x4, x5
	b.hs	2f
	ldp	x8, x9, [x4], #16
	stp	x8, x9, [x6], #16
	b	1b
2:	dsb	sy
	ic	iallu
	dsb	sy
	isb
	adrp	x0, dtb_start
	add	x0, x0, :lo12:dtb_start
	mov	x1, xzr
	mov	x2, xzr
	mov	x3, xzr
	br	x7
hang:	wfe
	b	hang

	.ltorg
	.balign	8
dtb_start:
	.incbin	DTB_PATH
	.balign	4096
kernel_start:
	.incbin	IMAGE_PATH
	.balign	16
kernel_end:
blob_end:

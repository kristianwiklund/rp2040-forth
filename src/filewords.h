	# -*- mode: asm -*-
	/*
	 * filewords.h — Storage / file-I/O Forth words.
	 *
	 * Included by forth.S (like compile.h, terminal.h, etc.).
	 * Calls into the VFS C layer (src/storage/vfs.h).
	 *
	 * Sprint 7: INCLUDE
	 * Sprint 8: OPEN-FILE  CLOSE-FILE  READ-FILE  WRITE-FILE  FILE-SIZE  (stubs)
	 *
	 * Register conventions (native words):
	 *   r5 = IP — must be saved/restored if used as a temp (push {r5} / pop {r5})
	 *   r4     — callee-saved (AAPCS); save if used as a temp
	 *   Native words end with DONE (not pop {pc}), because they are entered via
	 *   "mov pc,r1" (not bl), so lr does not hold a valid return address.
	 */

	.equ VFS_O_READ,  0x01
	.equ VFS_O_WRITE, 0x02
	.equ VFS_O_CREAT, 0x04
	.equ VFS_O_TRUNC, 0x08

	/* ------------------------------------------------------------------ */
	/* INCLUDE  ( "filename<nl>" -- )                                      */
	/*                                                                     */
	/* Parse the next whitespace-delimited token from the input stream as  */
	/* a VFS path, open the file, and push it onto the input source stack. */
	/* Subsequent input to the interpreter is drawn from that file until   */
	/* EOF, at which point the previous source is resumed automatically.   */
	/* ------------------------------------------------------------------ */

#: INCLUDE ( "filename<nl>" -- ) ; open a file and push it onto the input source stack
	HEADER "INCLUDE",7,0,INCLUDE
	push {r4,r5}		// save callee-saved regs used as temporaries

	/* Parse the next whitespace-delimited token → Forth stack: { addr, len } */
	bl newwordhelper
	KPOP			// r0 = length (not used; path is null-terminated)
	KPOP			// r0 = addr = wordbuf (null-terminated VFS path)

	/* vfs_open(path, VFS_O_READ) */
	mov r1, #VFS_O_READ
	bl vfs_open		// r0 = 1-based global fd; 0 = error

	cmp r0, #0
	beq _inc_done		// open failed: do nothing, fall through to DONE

	/* Push entry onto input_source_stack.
	   Each entry is 8 bytes: { int32 source_id=1, int32 vfs_fd }.
	   input_source_sp counts active entries (0 = empty). */

	mov r4, r0		// r4 = vfs fd (preserved across ldr/str)

	ldr r1, =input_source_sp
	ldr r2, [r1]		// r2 = current depth
	lsl r5, r2, #3		// r5 = depth × 8 (byte offset into stack array)
	ldr r3, =input_source_stack
	add r3, r5		// r3 = pointer to new entry

	mov r0, #1
	str r0, [r3]		// entry.source_id = 1 (file source)
	str r4, [r3, #4]	// entry.vfs_fd    = fd

	add r2, #1
	str r2, [r1]		// input_source_sp++

_inc_done:
	pop {r4,r5}
	DONE


	/* ------------------------------------------------------------------ */
	/* Sprint 8 — ANS file words                                          */
	/* These are functional for single-cell (non-64-bit) sizes.           */
	/* ------------------------------------------------------------------ */

	/* OPEN-FILE  ( addr u flags -- fh ior ) */
#: OPEN-FILE ( addr u flags -- fh ior ) ; open named file; fh=handle, ior=0 on success
	HEADER "OPEN-FILE",9,0,OPENFILE
	push {r4}

	KPOP			// r0 = Forth flags (ANS: 1=read, 2=write, 3=read/write)
	mov r4, r0		// r4 = flags

	KPOP			// r0 = u (length — not used; path must be C-string)

	KPOP			// r0 = addr (path — null-terminated)

	/* Map ANS flags to VFS flags (simplification: pass through low 4 bits). */
	mov r1, r4
	bl vfs_open		// r0 = fh (1-based) or 0 on error

	mov r4, r0		// r4 = fh
	KPUSH			// push fh

	cmp r4, #0
	bne _of_ok
	mov r0, #1		// ior = 1 (error)
	b _of_push
_of_ok:
	mov r0, #0		// ior = 0 (success)
_of_push:
	KPUSH			// push ior

	pop {r4}
	DONE


	/* CLOSE-FILE  ( fh -- ior ) */
#: CLOSE-FILE ( fh -- ior ) ; close a file handle; ior=0 on success
	HEADER "CLOSE-FILE",10,0,CLOSEFILE
	KPOP			// r0 = fh
	bl vfs_close		// void; always succeeds from caller's view
	mov r0, #0
	KPUSH			// ior = 0
	DONE


	/* READ-FILE  ( addr u fh -- u2 ior ) */
#: READ-FILE ( addr u fh -- u2 ior ) ; read up to u bytes into addr; u2=actual bytes; ior=0 ok
	HEADER "READ-FILE",9,0,READFILE
	push {r4,r5}

	KPOP			// r0 = fh
	mov r4, r0		// r4 = fh
	KPOP			// r0 = u (max bytes to read)
	mov r5, r0		// r5 = u
	KPOP			// r0 = addr (destination buffer)

	mov r2, r5		// r2 = len
	mov r1, r0		// r1 = buf
	mov r0, r4		// r0 = fh
	bl vfs_read		// r0 = bytes read (≥0) or -1 on error

	cmp r0, #0
	bge _rf_ok
	mov r0, #0		// clamp -1 → 0
_rf_ok:
	KPUSH			// push u2 (bytes read)
	mov r0, #0
	KPUSH			// push ior = 0

	pop {r4,r5}
	DONE


	/* WRITE-FILE  ( addr u fh -- ior ) */
#: WRITE-FILE ( addr u fh -- ior ) ; write u bytes from addr to fh; ior=0 on success
	HEADER "WRITE-FILE",10,0,WRITEFILE
	push {r4,r5}

	KPOP			// r0 = fh
	mov r4, r0		// r4 = fh
	KPOP			// r0 = u
	mov r5, r0		// r5 = u
	KPOP			// r0 = addr

	mov r2, r5		// r2 = len
	mov r1, r0		// r1 = buf
	mov r0, r4		// r0 = fh
	bl vfs_write		// r0 = bytes written or -1

	cmp r0, #0
	bge _wf_ok
	mov r0, #1		// ior = 1 (error)
	b _wf_push
_wf_ok:
	mov r0, #0		// ior = 0 (success)
_wf_push:
	KPUSH			// push ior

	pop {r4,r5}
	DONE


	/* FILE-SIZE  ( fh -- ud ior ) */
#: FILE-SIZE ( fh -- ud ior ) ; return file size as single-cell ud and ior
	HEADER "FILE-SIZE",9,0,FILESIZE
	KPOP			// r0 = fh
	bl vfs_size		// r0 = size (≥0) or -1

	cmp r0, #0
	bge _fsz_ok

	mov r0, #0
	KPUSH			// ud = 0
	mov r0, #1
	KPUSH			// ior = 1 (error)
	DONE

_fsz_ok:
	KPUSH			// ud = size
	mov r0, #0
	KPUSH			// ior = 0
	DONE

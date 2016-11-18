/*
Copyright 2016 Seth VanHeulen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "constants.h"

.org 0x80, 0
    .word 0x304f5243 // magic
    .word _cro_module_name // module name offset
    .word 0 // next cro pointer
    .word 0 // previous cro pointer
    .word _cro_file_end // file size
    .word 0 // .bss size
    .word 0 // unknown
    .word 0 // unknown
    .word 0 // nnroControlObject_ segment offset
    .word 0xffffffff // OnLoad segment offset
    .word 0xffffffff // OnExit segment offset
    .word 0xffffffff // OnUnresolved segment offset
    .word _cro_text_start // .text offset
    .word _cro_module_name-_cro_text_start // .text size
    .word _cro_data_start // .data offset
    .word _cro_data_end-_cro_data_start // .data size
    .word _cro_module_name // module name offset
    .word _cro_segment_table-_cro_module_name // module name size
    .word _cro_segment_table // segment table offset
    .word (_cro_named_export_table-_cro_segment_table)/0xc // segment table count
    .word _cro_named_export_table // named export table offset
    .word (_cro_export_tree-_cro_named_export_table)/8 // named export table count
    .word _cro_indexed_export_table // indexed export table offset
    .word (_cro_export_strings-_cro_indexed_export_table)/4 // indexed export table count
    .word _cro_export_strings // export strings offset
    .word _cro_import_module_table-_cro_export_strings // export strings size
    .word _cro_export_tree // export tree offset
    .word (_cro_indexed_export_table-_cro_export_tree)/8 // export tree count
    .word _cro_import_module_table // import module table offset
    .word (_cro_import_patches-_cro_import_module_table)/0x14 // import module table count
    .word _cro_import_patches // import patches offset
    .word (_cro_named_import_table-_cro_import_patches)/0xc // import patches count
    .word _cro_named_import_table // named import table offset
    .word (_cro_indexed_import_table-_cro_named_import_table)/8 // named import table count
    .word _cro_indexed_import_table // indexed import table offset
    .word (_cro_anon_import_table-_cro_indexed_import_table)/8 // indexed import table count
    .word _cro_anon_import_table // anonymous import table offset
    .word (_cro_import_strings-_cro_anon_import_table)/8 // anonymous import table count
    .word _cro_import_strings // import strings offset
    .word _cro_unknown1-_cro_import_strings // import strings size
    .word _cro_unknown1 // unknown offset
    .word 0 // unknown count
    .word _cro_relocation_patches // relocation patches offset
    .word (_cro_unknown2-_cro_relocation_patches)/0xc // relocation patches count
    .word _cro_unknown2 // unknown offset
    .word 0 // unknown count

.org 0x180, 0
_cro_text_start:
    // reset stack
    mov sp, #0x10000000
    bl main
    // exit if main returns
    svc 3

.align 2, 0
.arm
main:
    stmfd sp!, {r4-r6,lr}
    sub sp, sp, #0x14
    // open extdata archive
    mov r0, sp // archive handle pointer
    bl archive_open_extdata
    // open otherapp file
    mov r0, sp // archive handle pointer
    add r1, sp, #8 // file handle pointer
    mov r2, #1
    bl file_open_otherapp
    // get otherapp size
    add r0, sp, #8 // file handle pointer
    add r1, sp, #0xc // size output pointer
    bl file_get_size
    // round otherapp size to nearest page
    ldr r5, [sp,#0xc]
    ldr r0, =0xfff
    add r5, r5, r0
    bic r5, r5, r0
    // malloc linear for otherapp
    mov r0, r5 // size
    bl malloc_linear
    mov r4, r0
    // read otherapp file to linear
    add r0, sp, #8 // file handle pointer
    add r1, sp, #0xc // bytes read pointer
    mov r2, r4 // buffer
    ldr r3, [sp,#0xc] // size
    bl file_read
    // close otherapp file
    add r0, sp, #8 // file handle pointer
    bl file_close
    // close extdata archive
    mov r0, sp // archive handle pointer
    bl archive_close
    // flush data cache for linear buffer
    mov r0, r4 // addr
    mov r1, r5 // size
    bl flush_dcache
    // gspwn otherapp from linear buffer to code
    ldr r0, =OTHERAPP_VA // dst
    mov r1, r4 // src
    mov r2, r5 // size
    bl gspwn_aslr
    // clear instruction cache
    bl invalidate_icache
    // setup paramblk in linear buffer
    mov r0, r4
    ldr r2, =GX_TEXTURECOPY
    str r2, [r0, #0x1c]
    ldr r2, =GSPGPU_FLUSHDATACACHE
    str r2, [r0, #0x20]
    ldr r2, =GSPGPU_HANDLE_PTR
    str r2, [r0, #0x58]
    // jump to otherapp code
    mov r1, #0x10000000
    sub r1, r1, #4
    ldr r2, =OTHERAPP_VA
    blx r2
    add sp, sp, #0x14
    ldmfd sp!, {r4-r6,pc}

.pool

.align 2, 0
.arm
gspwn_aslr:
    stmfd sp!, {r4-r10,lr}
    mov r4, r0
    add r5, r0, r2
    lsr r6, r2, #0xc
    mov r7, r1
    mov r0, #0x1000 // size
    bl malloc_linear
    mov r8, r0
    ldr r9, =CODEBIN_START_LINEAR
_gspwn_aslr_linear_loop:
    mov r0, r8 // dst
    mov r1, r9 // src
    mov r2, #0x1000 // size
    bl gspwn
    mov r0, r8 // addr
    mov r1, #0x1000 // size
    bl invalidate_dcache
    mov r10, r4
_gspwn_aslr_virtual_loop:
    mov r0, r10 // addr1
    mov r1, r8 // addr2
    mov r2, #0x100 // size
    bl memcmp32
    cmp r0, #0
    beq _gspwn_aslr_found_page
    add r10, r10, #0x1000
    cmp r10, r5
    bne _gspwn_aslr_virtual_loop
    add r9, r9, #0x1000
    b _gspwn_aslr_linear_loop
_gspwn_aslr_found_page:
    mov r0, r9 // dst
    sub r1, r10, r4
    add r1, r1, r7 // src
    mov r2, #0x1000 // size
    bl gspwn
    add r9, r9, #0x1000
    sub r6, r6, #1
    cmp r6, #0
    bne _gspwn_aslr_linear_loop
    ldmfd sp!, {r4-r10,pc}

.pool

.align 2, 0
.arm
gspwn:
    stmfd sp!, {r4,lr}
    sub sp, sp, #0x10
    mov r3, r0
    mov r0, r1 // src
    mov r1, r3 // dst
    mov r3, #0 // input dimensions
    str r3, [sp] // output dimensions
    str r3, [sp,#4] // unused
    str r3, [sp,#8] // unused
    mov r4, #8
    str r4, [sp,#0xc] // flags
    ldr r4, =GX_TEXTURECOPY
    blx r4
    mov r0, #0x100000 // nanoseconds (low)
    mov r1, #0 // nanoseconds (high)
    svc 0xa
    add sp, sp, #0x10
    ldmfd sp!, {r4,pc}

.pool

.align 2, 0
.arm
memcmp32:
    stmfd sp!, {r4,lr}
_memcmp32_compare_loop:
    ldr r3, [r0],#4
    ldr r4, [r1],#4
    cmp r3, r4
    movne r0, #1
    bne _memcmp32_return
    sub r2, r2, #4
    cmp r2, #0
    bne _memcmp32_compare_loop
    mov r0, #0
_memcmp32_return:
    ldmfd sp!, {r4,pc}

.align 2, 0
.arm
malloc_heap:
    mov r1, r0 // size
    ldr r0, =MTCTRHEAPALLOCATOR_INSTANCE_PTR
    ldr r0, [r0] // this
    mov r2, #0x1000 // alignment
    ldr r3, =MTCTRHEAPALLOCATOR_MALLOC
    bx r3

.pool

.align 2, 0
.arm
malloc_linear:
    mov r1, r0 // size
    ldr r0, =MTEXHEAPALLOCATOR_INSTANCE_PTR
    ldr r0, [r0] // this
    mov r2, #0x1000 // alignment
    ldr r3, =MTEXHEAPALLOCATOR_MALLOC
    bx r3

.pool

.align 2, 0
.arm
flush_dcache:
    ldr r2, =GSPGPU_FLUSHDATACACHE
    bx r2

.pool

.align 2, 0
.arm
invalidate_dcache:
    stmfd sp!, {r4,lr}
    mrc p15, 0, r4, c13, c0, 3
    ldr r2, =0x90082 // header code
    str r2, [r4,#0x80]!
    str r0, [r4,#4] // addr
    str r1, [r4,#8] // size
    mov r2, #0
    str r2, [r4,#0xc] // zero
    ldr r2, =0xffff8001
    str r2, [r4,#0x10] // kprocess handle
    ldr r0, =GSPGPU_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    and r1, r0, #0x80000000
    cmp r1, #0
    ldrge r0, [r4,#4]
    ldmfd sp!, {r4,pc}

.pool

.align 2, 0
.arm
invalidate_icache:
    stmfd sp!, {r4,r5,lr}
    sub sp, sp, #4
    mov r0, #ICACHE_SIZE+0x2000 // size
    bl malloc_heap
    mov r4, r0 // addr
    mov r1, #ICACHE_SIZE+0x2000 // size
    bl memclr32
    mov r0, r4 // dst
    adr r1, nopsled_header // src
    mov r2, #nopsled_tables-nopsled_header // size
    bl memcpy
    add r0, r4, #ICACHE_SIZE+0x1000 // dst
    adr r1, nopsled_tables // src
    mov r2, #nopsled_crr_hash-nopsled_tables // size
    bl memcpy
    add r0, r4, #ICACHE_SIZE
    add r0, r0, #0x180
    ldr r1, =0xe12fff1e
    str r1, [r0]
    adr r0, nopsled_crr_hash // hash
    bl patch_crr
    ldr r5, =CRO_MAP_FIX
    sub r5, r4, r5
    mov r0, sp // fixed size
    mov r1, r4 // addr
    mov r2, r5 // mapped addr
    mov r3, #ICACHE_SIZE+0x2000 // size
    bl load_cro
    add r5, r5, #0x180
    blx r5
    add sp, sp, #4
    ldmfd sp!, {r4,r5,pc}

.pool
nopsled_header:
.incbin CRO_FILE_PATH, 0, 0x134
nopsled_tables:
.incbin CRO_FILE_PATH, ICACHE_SIZE+0x1000, 0x70
nopsled_crr_hash:
.incbin CRO_FILE_PATH, ICACHE_SIZE+0x2000-0x20, 0x20

.align 2, 0
.arm
memclr32:
    mov r2, #0
_memclr32_clear_loop:
    str r2, [r0],#4
    sub r1, r1, #4
    cmp r1, #0
    bne _memclr32_clear_loop
    bx lr

.align 2, 0
.arm
memcpy:
    ldr r3, =MEMCPY
    bx r3

.pool

.align 2, 0
.arm
patch_crr:
    stmfd sp!, {r4-r6,lr}
    mov r4, r0
    mov r0, #CRR_HASH_COUNT*0x20 // size
    bl malloc_linear
    mov r5, r0
    mov r6, #0
_patch_crr_copy_loop:
    add r0, r5, r6 // dst
    mov r1, r4 // src
    mov r2, #0x20 // size
    bl memcpy
    add r6, r6, #0x20
    cmp r6, #CRR_HASH_COUNT*0x20
    bne _patch_crr_copy_loop
    mov r0, r5 // addr
    mov r2, #CRR_HASH_COUNT*0x20 // size
    bl flush_dcache
    ldr r0, =CRR_START_LINEAR+0x360 // dst
    mov r1, r5 // src
    mov r2, #CRR_HASH_COUNT*0x20 // size
    bl gspwn
    ldmfd sp!, {r4-r6,pc}

.pool

.align 2, 0
.arm
load_cro:
    stmfd sp!, {r4,r5,lr}
    mrc p15, 0, r4, c13, c0, 3
    mov r5, r0
    ldr r0, =0x902c2 // header code
    str r0, [r4,#0x80]!
    add r0, r4, #4
    stmia r0, {r1-r3} // addr, mapped addr, size
    mov r0, #0
    mov r1, #1
    str r0, [r4,#0x10] // data addr
    str r0, [r4,#0x14] // zero
    str r0, [r4,#0x18] // data size
    str r0, [r4,#0x1c] // bss addr
    str r0, [r4,#0x20] // bss size
    str r1, [r4,#0x24] // auto-link
    str r1, [r4,#0x28] // fix level
    str r0, [r4,#0x2c] // zero
    str r0, [r4,#0x30] // zero
    ldr r0, =0xffff8001
    str r0, [r4,#0x34] // kprocess handle
    ldr r0, =LDRRO_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    ands r1, r0, #0x80000000
    bmi _load_cro_return
    ldr r0, [r4,#8]
    str r0, [r5] // fixed size
    ldr r0, [r4,#4]
_load_cro_return:
    ldmfd sp!, {r4,r5,pc}

.pool

.align 2, 0
.arm
archive_open_extdata:
    stmfd sp!, {r4-r7,lr}
    mrc p15, 0, r4, c13, c0, 3
    mov r5, r0
    ldr r0, =0x80c00c2 // header code
    str r0, [r4,#0x80]!
    mov r0, #6 // archive id
    mov r1, #2 // path type
    mov r2, #0xc // path size
    ldr r3, =(0xc<<14)|2 // path size
    adr r6, extdata_path // path
    add r7, r4, #4
    stmia r7, {r0-r3,r6}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    ands r1, r0, #0x80000000
    bmi _archive_open_extdata_return
    ldrd r0, [r4,#8]
    strd r0, [r5] // archive handle
    ldr r0, [r4,#4]
_archive_open_extdata_return:
    ldmfd sp!, {r4-r7,pc}

.pool
extdata_path:
    .word 0x1
    .word EXTDATA_ID
    .word 0

.align 2, 0
.arm
file_open_otherapp:
    stmfd sp!, {r4-r11,lr}
    mrc p15, 0, r4, c13, c0, 3
    mov r5, r1
    mov r7, r2 // open flags
    ldrd r0, [r0]
    mov r2, r1 // archive handle (high)
    mov r1, r0 // archive handle (low)
    ldr r0, =0x80201c2 // header code
    str r0, [r4,#0x80]!
    mov r0, #0 // zero
    mov r3, #3 // path type
    mov r6, #0xa // path size
    mov r8, #0 // attributes
    ldr r9, =(0xa<<14)|2 // path size
    adr r10, otherapp_path // path
    add r11, r4, #4
    stmia r11, {r0-r3,r6-r10}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    ands r1, r0, #0x80000000
    bmi _file_open_otherapp_return
    ldr r0, [r4,#0xc]
    str r0, [r5] // file handle
    ldr r0, [r4,#4]
_file_open_otherapp_return:
    ldmfd sp!, {r4-r11,pc}

.pool
otherapp_path:
    .asciz "/otherapp"

.align 2, 0
.arm
archive_close:
    stmfd sp!, {r4,lr}
    mrc p15, 0, r4, c13, c0, 3
    ldr r1, =0x80e0080 // header code
    str r1, [r4,#0x80]!
    ldrd r0, [r0]
    strd r0, [r4,#4] // archive handle
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    and r1, r0, #0x80000000
    cmp r1, #0
    ldrge r0, [r4,#4]
    ldmfd sp!, {r4,pc}

.pool

.align 2, 0
.arm
file_get_size:
    stmfd sp!, {r4,r5,lr}
    mrc p15, 0, r4, c13, c0, 3
    ldr r5, =0x8040000 // header code
    str r5, [r4,#0x80]!
    mov r5, r1
    ldr r0, [r0] // file handle
    svc 0x32
    ands r1, r0, #0x80000000
    bmi _file_get_size_return
    ldrd r0, [r4,#8]
    strd r0, [r5] // size
    ldr r0, [r4,#4]
_file_get_size_return:
    ldmfd sp!, {r4,r5,pc}

.pool

.align 2, 0
.arm
file_read:
    stmfd sp!, {r4,r5,lr}
    mrc p15, 0, r4, c13, c0, 3
    ldr r5, =0x80200c2 // header code
    str r5, [r4,#0x80]!
    mov r5, #0
    str r5, [r4,#4] // offset (low)
    str r5, [r4,#8] // offset (high)
    str r3, [r4,#0xc] // size
    mov r5, #0xc
    orr r5, r5, r3,lsl#4
    str r5, [r4,#0x10] // size
    str r2, [r4,#0x14] // buffer
    mov r5, r1
    ldr r0, [r0] // file handle
    svc 0x32
    ands r1, r0, #0x80000000
    bmi _file_read_return
    ldr r0, [r4,#0x8]
    str r0, [r5] // bytes read
    ldr r0, [r4,#4]
_file_read_return:
    ldmfd sp!, {r4,r5,pc}

.pool

.align 2, 0
.arm
file_close:
    stmfd sp!, {r4,lr}
    mrc p15, 0, r4, c13, c0, 3
    ldr r1, =0x8080000 // header code
    str r1, [r4,#0x80]!
    ldr r0, [r0] // file handle
    svc 0x32
    and r1, r0, #0x80000000
    cmp r1, #0
    ldrge r0, [r4,#4]
    ldmfd sp!, {r4,pc}

.pool

_cro_text_end:

.align 12, 0
_cro_rodata_start:
_cro_rodata_end:

.align 12, 0
_cro_module_name:
    .asciz "payload"
_cro_segment_table:
    .word _cro_text_start, _cro_text_end-_cro_text_start, 0
    .word _cro_rodata_start, _cro_rodata_end-_cro_rodata_start, 1
    .word _cro_data_start, _cro_data_end-_cro_data_start, 2
    .word 0, 0, 0
    .word 0, 0, 0
_cro_named_export_table:
    .word _cro_export_strings, 0
_cro_export_tree:
    .word 0x1ffff, 0
    .word 0x80000000, 0x8001
_cro_indexed_export_table:
_cro_export_strings:
    .asciz "nnroControlObject_"
_cro_import_module_table:
_cro_import_patches:
_cro_named_import_table:
_cro_indexed_import_table:
_cro_anon_import_table:
_cro_import_strings:
_cro_unknown1:
_cro_relocation_patches:
_cro_unknown2:
_cro_data_start:
_cro_data_end:

.align 12, 0xcc
_cro_file_end:


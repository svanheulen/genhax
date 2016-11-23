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
    .ascii "CRO0" // magic
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
    blx main
    // exit if main returns
    svc 3

.align 1
.thumb
main:
    push {r4-r6,lr}
    sub sp, #0x14
    // open extdata archive
    add r0, sp, #0x8 // archive handle pointer
    mov r1, #6 // archive id
    mov r2, #2 // path type
    mov r3, #0xc // path size
    adr r4, extdata_archive_path
    str r4, [sp]
    bl FSUSER_OpenArchive
    // open otherapp file
    add r0, sp, #0x10 // file handle pointer
    add r1, sp, #0x8 // archive handle pointer
    mov r2, #3 // path type
    mov r3, #0xa // path size
    mov r4, #1
    str r4, [sp] // open flags
    adr r4, otherapp_file_path
    str r4, [sp,#4] // path
    bl FSUSER_OpenFile
    // get otherapp size
    add r0, sp, #0x10 // file handle pointer
    mov r1, sp // size output pointer
    bl FSFILE_GetSize
    // round otherapp size to nearest page
    ldr r6, [sp]
    ldr r0, =0xfff
    add r6, r6, r0
    bic r6, r0
    // malloc linear for otherapp
    mov r0, r6 // size
    bl malloc_linear
    mov r5, r0
    // read otherapp file to linear
    add r0, sp, #0x10 // file handle pointer
    mov r1, sp // bytes read pointer
    mov r2, #0 // file offset (low)
    mov r3, #0 // file offset (high)
    str r5, [sp,#4] // buffer
    bl FSFILE_Read
    // close otherapp file
    add r0, sp, #0x10 // file handle pointer
    bl FSFILE_Close
    // close extdata archive
    add r0, sp, #0x8 // archive handle pointer
    bl FSUSER_CloseArchive
    // flush data cache for linear buffer
    mov r0, r5 // addr
    mov r1, r6 // size
    bl GSPGPU_FlushDataCache
    // gspwn otherapp from linear buffer to code
    ldr r0, =OTHERAPP_VA // dst
    mov r1, r5 // src
    mov r2, r6 // size
    bl gspwn_aslr
    // clear instruction cache
    bl invalidate_icache
    // setup paramblk in linear buffer
    ldr r0, =GX_TEXTURECOPY
    str r0, [r5, #0x1c]
    ldr r0, =GSPGPU_FLUSHDATACACHE
    str r0, [r5, #0x20]
    ldr r0, =GSPGPU_HANDLE_PTR
    str r0, [r5, #0x58]
    // jump to otherapp code
    mov r0, r5
    ldr r1, =0x0ffffffc
    ldr r2, =OTHERAPP_VA
    blx r2
    add sp, #0x14
    pop {r4-r6,pc}
.pool
extdata_archive_path:
    .word 0x1
    .word EXTDATA_ID
    .word 0
otherapp_file_path:
    .asciz "/otherapp"

.align 1
.thumb
malloc_heap: // size
    mov r1, r0 // size
    ldr r0, =MTCTRHEAPALLOCATOR_INSTANCE_PTR
    ldr r0, [r0] // this
    mov r2, #1
    lsl r2, r2, #0xc // alignment
    ldr r3, =MTCTRHEAPALLOCATOR_MALLOC
    bx r3
.pool

.align 1
.thumb
malloc_linear: // size
    mov r1, r0 // size
    ldr r0, =MTEXHEAPALLOCATOR_INSTANCE_PTR
    ldr r0, [r0] // this
    mov r2, #1
    lsl r2, r2, #0xc // alignment
    ldr r3, =MTEXHEAPALLOCATOR_MALLOC
    bx r3
.pool

.align 1
.thumb
memcpy: // dst, src, size
    ldr r3, =MEMCPY
    bx r3
.pool

.align 1
.thumb
memclr32: // addr, size
    mov r2, #0
memset32: // addr, size, value
    mov r3, #3
    bic r1, r3
_memset32_set_loop:
    str r2, [r0]
    add r0, r0, #4
    sub r1, r1, #4
    bne _memset32_set_loop
    bx lr

.align 1
.thumb
memcmp32: // addr1, addr2, size
    push {r4,lr}
    mov r3, #3
    bic r2, r3
_memcmp32_compare_loop:
    ldr r3, [r0]
    add r0, r0, #4
    ldr r4, [r1]
    add r1, r1, #4
    cmp r3, r4
    bne _memcmp32_mismatch
    sub r2, r2, #4
    bne _memcmp32_compare_loop
    mov r0, #0
    pop {r4,pc}
_memcmp32_mismatch:
    mov r0, #1
    pop {r4,pc}

.align 1
.thumb
screen_setup: // framebuffers_ptr
    push {r4,lr}
    mov r4, r0
    ldr r0, =400*240*2
    bl malloc_linear
    str r0, [r4]
    mov r1, #0
    bl GSPGPU_SetBufferSwap
    mov r0, r4
    mov r1, #0
    mov r2, #0
    bl screen_clear
    ldr r0, =320*240*2
    bl malloc_linear
    str r0, [r4,#4]
    mov r1, #1
    bl GSPGPU_SetBufferSwap
    mov r0, r4
    mov r1, #1
    mov r2, #0
    bl screen_clear
    pop {r4,pc}
.pool

.align 1
.thumb
screen_clear: // framebuffers_ptr, screen, color
    lsl r3, r2
    orr r2, r3
    cmp r1, #0
    bne _screen_clear_bottom
    ldr r0, [r0]
    ldr r1, =400*240*2
    b memset32
_screen_clear_bottom:
    ldr r0, [r0,#4]
    ldr r1, =320*240*2
    b memset32
.pool

.align 1
.thumb
screen_print: // framebuffers_ptr, screen, x, y, string, color
    push {r4,r5,lr}
    lsl r1, r1, #2
    ldr r4, [r0,r1]
    ldr r0, =240*2
    mul r2, r0
    add r4, r4, r2
    lsl r3, r3, #1
    add r4, r4, r3
    ldr r5, [sp,#0xc]
_screen_print_char_loop:
    ldrb r3, [r5]
    cmp r3, #0
    beq _screen_print_return
    cmp r3, #0x2d
    blt _screen_print_default_char
    cmp r3, #0x3a
    ble _screen_print_num_sym
    cmp r3, #0x41
    blt _screen_print_default_char
    cmp r3, #0x5a
    ble _screen_print_alpha
_screen_print_default_char:
    mov r3, #0
    b _screen_print_setup_bit_loop
_screen_print_alpha:
    sub r3, r3, #6
_screen_print_num_sym:
    sub r3, r3, #0x2d
    lsl r3, r3, #2
    adr r0, font_data
    add r3, r3, r0
    ldr r3, [r3]
_screen_print_setup_bit_loop:
    mov r0, #6
    mov r1, #5
_screen_print_bit_loop:
    lsl r2, r3, #0x1f
    ldr r2, [sp,#0x10]
    bne _screen_print_foreground
    mov r2, #0
_screen_print_foreground:
    strh r2, [r4]
    lsr r3, r3, #1
    add r4, r4, #2
    sub r0, r0, #1
    bne _screen_print_bit_loop
    ldr r0, =240*2
    sub r0, r0, #0xc
    add r4, r4, r0
    mov r0, #6
    sub r1, r1, #1
    bne _screen_print_bit_loop
    ldr r0, =240*2
    add r4, r4, r0
    add r5, r5, #1
    b _screen_print_char_loop
_screen_print_return:
    pop {r4,r5,pc}
.pool
font_data:
    .word 0x08208208, 0x00001000, 0x2040c081, 0x1e86d85e, 0x0007f440 // - . / 0 1
    .word 0x199658d1, 0x16a69852, 0x3f10413c, 0x26a69a79, 0x26a69a5e // 2 3 4 5 6
    .word 0x30a248a1, 0x16a69a56, 0x1e965959, 0x00012000, 0x0f52450f // 7 8 9 : A
    .word 0x16a69a7f, 0x2186185e, 0x1e86187f, 0x21a69a7f, 0x20a28a3f // B C D E F
    .word 0x2ea6985e, 0x3f20823f, 0x0087f840, 0x0083e841, 0x2350823f // G H I J K
    .word 0x0104107f, 0x3f40843f, 0x3f08c43f, 0x1e86185e, 0x1892493f // L M N O P
    .word 0x1d8a585e, 0x17a28a3f, 0x26a69a51, 0x2083f820, 0x3e04107e // Q R S T U
    .word 0x3c0810bc, 0x3f0840bf, 0x2148c4a1, 0x30207230, 0x31a69963 // V W X Y Z

.align 1
.thumb
gspwn_aslr: // dst, src, size
    push {r4-r7,lr}
    mov r4, r0
    add r5, r0, r2
    lsr r6, r2, #0xc
    ldr r7, =CODEBIN_START_LINEAR
    mov r8, r1
    ldr r0, =0x1000 // size
    bl malloc_linear
    mov r9, r0
_gspwn_aslr_linear_loop:
    mov r0, r9 // dst
    mov r1, r7 // src
    ldr r2, =0x1000 // size
    bl gspwn
    mov r0, r9 // addr
    ldr r1, =0x1000 // size
    bl GSPGPU_InvalidateDataCache
    mov r10, r4
_gspwn_aslr_virtual_loop:
    mov r0, r10 // addr1
    mov r1, r9 // addr2
    ldr r2, =0x100 // size
    bl memcmp32
    cmp r0, #0
    beq _gspwn_aslr_found_page
    ldr r0, =0x1000
    add r10, r0
    cmp r10, r5
    bne _gspwn_aslr_virtual_loop
    add r7, r7, r0
    b _gspwn_aslr_linear_loop
_gspwn_aslr_found_page:
    mov r0, r7 // dst
    mov r1, r10
    sub r1, r1, r4
    add r1, r8 // src
    ldr r2, =0x1000 // size
    bl gspwn
    ldr r0, =0x1000
    add r7, r7, r0
    sub r6, r6, #1
    bne _gspwn_aslr_linear_loop
    pop {r4-r7,pc}
.pool

.align 1
.thumb
gspwn: // dst, src, size
    push {r4,lr}
    sub sp, #0x10
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
    mov r0, #1
    lsl r0, r0, #0x14
    mov r1, #0
    svc 0xa
    add sp, #0x10
    pop {r4,pc}

.align 1
.thumb
invalidate_icache:
    push {r4,r5,lr}
    sub sp, #4
    ldr r0, =ICACHE_SIZE+0x2000 // size
    bl malloc_heap
    mov r4, r0 // addr
    ldr r1, =ICACHE_SIZE+0x2000 // size
    bl memclr32
    mov r0, r4 // dst
    adr r1, nopsled_header // src
    mov r2, #0xff
    add r2, r2, #0x35 // size
    bl memcpy
    ldr r0, =ICACHE_SIZE+0x1000
    add r0, r0, r4 // dst
    adr r1, nopsled_tables // src
    mov r2, #0x70 // size
    bl memcpy
    ldr r0, =ICACHE_SIZE+0x180
    add r0, r0, r4
    ldr r1, =0xe12fff1e
    str r1, [r0]
    adr r0, nopsled_crr_hash // hash
    bl patch_crr
    ldr r5, =CRO_MAP_FIX
    sub r5, r4, r5
    mov r0, sp // fixed size
    mov r1, r4 // addr
    mov r2, r5 // mapped addr
    ldr r3, =ICACHE_SIZE+0x2000 // size
    bl LDRRO_LoadCRO_New
    add r5, r5, #0xff
    add r5, r5, #0x81
    blx r5
    add sp, #4
    pop {r4,r5,pc}
.pool
nopsled_header:
    .incbin CRO_FILE_PATH, 0, 0x134
nopsled_tables:
    .incbin CRO_FILE_PATH, ICACHE_SIZE+0x1000, 0x70
nopsled_crr_hash:
    .incbin CRO_FILE_PATH, ICACHE_SIZE+0x2000-0x20, 0x20

.align 1
.thumb
patch_crr: // hash_ptr
    push {r4-r6,lr}
    mov r4, r0
    ldr r0, =CRR_HASH_COUNT*0x20 // size
    bl malloc_linear
    mov r5, r0
    mov r6, #0
_patch_crr_copy_loop:
    add r0, r5, r6 // dst
    mov r1, r4 // src
    mov r2, #0x20 // size
    bl memcpy
    add r6, r6, #0x20
    ldr r0, =CRR_HASH_COUNT*0x20
    cmp r6, r0
    bne _patch_crr_copy_loop
    mov r0, r5 // addr
    ldr r1, =CRR_HASH_COUNT*0x20 // size
    bl GSPGPU_FlushDataCache
    ldr r0, =CRR_START_LINEAR+0x360 // dst
    mov r1, r5 // src
    ldr r2, =CRR_HASH_COUNT*0x20 // size
    bl gspwn
    pop {r4-r6,pc}
.pool

.align 2
.arm
_get_command_buffer:
    mrc p15, 0, r0, c13, c0, 3
    add r0, r0, #0x80
    bx lr

.align 1
.thumb
FSUSER_OpenFile: // file_handle_ptr, archive_handle_ptr, path_type, path_size, open_flags, path
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80201c2
    str r0, [r4] // header code
    mov r0, #0
    str r0, [r4,#4] // transaction
    ldr r0, [r1]
    str r0, [r4,#8] // archive handle (low)
    ldr r0, [r1,#4]
    str r0, [r4,#0xc] // archive handle (high)
    str r2, [r4,#0x10] // path type
    str r3, [r4,#0x14] // path size
    ldr r0, [sp,#0xc]
    str r0, [r4,#0x18] // open flags
    mov r0, #0
    str r0, [r4,#0x1c] // attributes
    lsl r3, r3, #0xe
    mov r0, #2
    orr r3, r0
    str r3, [r4,#0x20] // path size
    ldr r0, [sp,#0x10]
    str r0, [r4,#0x24] // path
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_OpenFile_return
    ldr r0, [r4,#0xc]
    str r0, [r5] // file handle
    ldr r0, [r4,#4]
_FSUSER_OpenFile_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSUSER_DeleteFile: // archive_handle_ptr, path_type, path_size, path
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8040142
    str r0, [r4] // header code
    mov r0, #0
    str r0, [r4,#4] // transaction
    ldr r0, [r5]
    str r0, [r4,#8] // archive handle (low)
    ldr r0, [r5,#4]
    str r0, [r4,#0xc] // archive handle (high)
    str r1, [r4,#0x10] // path type
    str r2, [r4,#0x14] // path size
    lsl r2, r2, #0xe
    mov r0, #2
    orr r2, r0
    str r2, [r4,#0x18] // path size
    str r3, [r4,#0x1c] // path
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_DeleteFile_return
    ldr r0, [r4,#4]
_FSUSER_DeleteFile_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSUSER_CreateFile: // archive_handle_ptr, path_type, path_size, file_size_low, file_size_high, path
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8080202
    str r0, [r4] // header code
    mov r0, #0
    str r0, [r4,#4] // transaction
    ldr r0, [r5]
    str r0, [r4,#8] // archive handle (low)
    ldr r0, [r5,#4]
    str r0, [r4,#0xc] // archive handle (high)
    str r1, [r4,#0x10] // path type
    str r2, [r4,#0x14] // path size
    mov r0, #0
    str r0, [r4,#0x18] // attributes
    str r3, [r4,#0x1c] // file size (low)
    ldr r0, [sp,#0xc]
    str r0, [r4,#0x20] // file size (high)
    lsl r2, r2, #0xe
    mov r0, #2
    orr r2, r0
    str r2, [r4,#0x24] // path size
    ldr r0, [sp,#0x10]
    str r0, [r4,#0x28] // path
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_CreateFile_return
    ldr r0, [r4,#4]
_FSUSER_CreateFile_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSUSER_OpenArchive: // archive_handle_ptr, archive_id, path_type, path_size, path
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80c00c2
    str r0, [r4] // header code
    str r1, [r4,#4] // archive id
    str r2, [r4,#8] // path type
    str r3, [r4,#0xc] // path size
    lsl r3, r3, #0xe
    mov r0, #2
    orr r3, r0
    str r3, [r4,#0x10] // path size
    ldr r0, [sp,#0xc]
    str r0, [r4,#0x14] // path
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_OpenArchive_return
    ldr r0, [r4,#8]
    str r0, [r5] // archive handle (low)
    ldr r0, [r4,#0xc]
    str r0, [r5,#4] // archive handle (high)
    ldr r0, [r4,#4]
_FSUSER_OpenArchive_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSUSER_CloseArchive: // archive_handle_ptr
    push {r4,lr}
    mov r2, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80e0080
    str r0, [r4] // header code
    ldr r0, [r2]
    str r0, [r4,#4] // archive handle (low)
    ldr r0, [r2,#4]
    str r0, [r4,#8] // archive handle (high)
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_CloseArchive_return
    ldr r0, [r4,#4]
_FSUSER_CloseArchive_return:
    pop {r4,pc}
.pool

.align 1
.thumb
FSFILE_Read: // file_handle_ptr, bytes_read_ptr, file_offset_low, file_offset_high, size, buffer
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80200c2
    str r0, [r4] // header code
    str r2, [r4,#4] // file offset (low)
    str r3, [r4,#8] // file offset (high)
    ldr r0, [sp,#0xc]
    str r0, [r4,#0xc] // size
    lsl r0, r0, #4
    mov r2, #0xc
    orr r0, r2
    str r0, [r4,#0x10] // size
    ldr r0, [sp,#0x10]
    str r0, [r4,#0x14] // buffer
    ldr r0, [r5] // file handle
    mov r5, r1
    svc 0x32
    cmp r0, #0
    blt _FSFILE_Read_return
    ldr r0, [r4,#0x8]
    str r0, [r5] // bytes read
    ldr r0, [r4,#4]
_FSFILE_Read_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSFILE_Write: // file_handle_ptr, bytes_written_ptr, file_offset_low, file_offset_high, size, buffer
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8030102
    str r0, [r4] // header code
    str r2, [r4,#4] // file offset (low)
    str r3, [r4,#8] // file offset (high)
    ldr r0, [sp,#0xc]
    str r0, [r4,#0xc] // size
    mov r0, #1
    str r0, [r4,#0x10] // write option
    lsl r0, r0, #4
    mov r2, #0xa
    orr r0, r2
    str r0, [r4,#0x14] // size
    ldr r0, [sp,#0x10]
    str r0, [r4,#0x18] // buffer
    ldr r0, [r5] // file handle
    mov r5, r1
    svc 0x32
    cmp r0, #0
    blt _FSFILE_Write_return
    ldr r0, [r4,#0x8]
    str r0, [r5] // bytes written
    ldr r0, [r4,#4]
_FSFILE_Write_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSFILE_GetSize: // file_handle_ptr, file_size_ptr
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8040000
    str r0, [r4] // header code
    ldr r0, [r5] // file handle
    mov r5, r1
    svc 0x32
    cmp r0, #0
    blt _FSFILE_GetSize_return
    ldr r0, [r4,#8]
    str r0, [r5] // file size (low)
    ldr r0, [r4,#0xc]
    str r0, [r5,#4] // file size (high)
    ldr r0, [r4,#4]
_FSFILE_GetSize_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
FSFILE_Close: // file_handle_ptr
    push {r4,lr}
    mov r1, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8080000
    str r0, [r4] // header code
    ldr r0, [r1] // file handle
    svc 0x32
    cmp r0, #0
    blt _FSFILE_Close_return
    ldr r0, [r4,#4]
_FSFILE_Close_return:
    pop {r4,pc}
.pool

.align 1
.thumb
GSPGPU_FlushDataCache: // addr, size
    ldr r2, =GSPGPU_FLUSHDATACACHE
    bx r2
.pool

.align 1
.thumb
GSPGPU_InvalidateDataCache: // addr, size
    push {r4,lr}
    mov r2, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x90082
    str r0, [r4] // header code
    str r2, [r4,#4] // addr
    str r1, [r4,#8] // size
    mov r0, #0
    str r0, [r4,#0xc] // zero
    ldr r0, =0xffff8001
    str r0, [r4,#0x10] // kprocess handle
    ldr r0, =GSPGPU_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _GSPGPU_InvalidateDataCache_return
    ldr r0, [r4,#4]
_GSPGPU_InvalidateDataCache_return:
    pop {r4,pc}
.pool

.align 1
.thumb
GSPGPU_SetBufferSwap: // framebuffer_addr, screen
    push {r4,lr}
    mov r2, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x50200
    str r0, [r4] // header code
    str r1, [r4,#4] // screen
    mov r0, #0
    str r0, [r4,#8] // active framebuffer
    str r2, [r4,#0xc] // framebuffer addr (left)
    str r2, [r4,#0x10] // framebuffer addr (right)
    ldr r2, =0x1e0
    str r2, [r4,#0x14] // stride
    mov r2, #2
    cmp r1, #0
    bne _GSPGPU_SetBufferSwap_bottom
    add r2, r2, #0xff
    add r2, r2, #0x41
_GSPGPU_SetBufferSwap_bottom:
    mov r2, #2
    str r2, [r4,#0x18] // format
    str r0, [r4,#0x1c] // framebuffer select
    str r0, [r4,#0x20] // unknown
    ldr r0, =GSPGPU_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _GSPGPU_SetBufferSwap_return
    ldr r0, [r4,#4]
_GSPGPU_SetBufferSwap_return:
    pop {r4,pc}
.pool

.align 1
.thumb
LDRRO_LoadCRO_New: // fixed_size, addr, mapped_addr, size
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x902c2
    str r0, [r4] // header code
    str r1, [r4,#4] // addr
    str r2, [r4,#8] // mapped addr
    str r3, [r4,#0xc] // size
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
    cmp r0, #0
    blt _LDRRO_LoadCRO_New_return
    ldr r0, [r4,#8]
    str r0, [r5] // fixed size
    ldr r0, [r4,#4]
_LDRRO_LoadCRO_New_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
SRV_GetServiceHandle: // handle_ptr, name, name_len
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x50100
    str r0, [r4] // header code
    ldr r0, [r1]
    str r0, [r4,#4] // name (low)
    ldr r0, [r1,#4]
    str r0, [r4,#8] // name (high)
    str r2, [r4,#0xc] // name size
    mov r0, #0
    str r0, [r4,#0x10] // flags
    ldr r0, =SRV_HANDLE_PTR
    ldr r0, [r0] // port handle
    svc 0x32
    cmp r0, #0
    blt _SRV_GetServiceHandle_return
    ldr r0, [r4,#0xc]
    str r0, [r5] // service handle
    ldr r0, [r4,#4]
_SRV_GetServiceHandle_return:
    pop {r4,r5,pc}
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


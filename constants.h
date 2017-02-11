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

#if defined(JPN)
    #define REGION_CONST(jpn, eur, usa) jpn
#elif defined(EUR)
    #define REGION_CONST(jpn, eur, usa) eur
#elif defined(USA)
    #define REGION_CONST(jpn, eur, usa) usa
#else
    #error "No region selected."
#endif

// rop gadgets
#define ROP_POP_R0PC REGION_CONST(0x11ae9c, 0x1271d4, 0x1271d4)
#define ROP_POP_R1PC REGION_CONST(0x2fb5d4, 0x2f2000, 0x2f2000)
#define ROP_POP_R1R2R3PC REGION_CONST(0x81cedc, 0x838a6c, 0x838a34)
#define ROP_POP_LRPC REGION_CONST(0x1199b4, 0x12496c, 0x12496c)
#define ROP_POP_PC REGION_CONST(0x10fc40, 0x11ac38, 0x11ac38)
#define ROP_LDR_R0R0_BX_LR REGION_CONST(0x1191a8, 0x124160, 0x124160)
#define ROP_MOV_R5R0_BLX_R1 REGION_CONST(0x29a398, 0x2a7460, 0x2a7460)
#define ROP_MOV_R0R5_BLX_R1 REGION_CONST(0x1164d4, 0x12148c, 0x12148c)
#define ROP_MOV_R6R0_BLX_R1 REGION_CONST(0x7a02d0, 0x7bba58, 0x7bba58)
#define ROP_MOV_R1R6_BLX_R3 REGION_CONST(0x16bcd4, 0x178228, 0x178228)
#define ROP_MOV_R0SP_BLX_R3 REGION_CONST(0x7212a4, 0x73ca2c, 0x73ca2c)
#define ROP_ADD_R0R0R1_BX_LR REGION_CONST(0x1cc1e8, 0x1d8be8, 0x1d8be8)
#define ROP_ADD_SPSP12_POP_PC REGION_CONST(0x1135c8, 0x11e580, 0x11e580)
#define ROP_ADD_SPSP16_POP_PC REGION_CONST(0x3002da+1, 0x2fbe7a+1, 0x2fbe7a+1)
// functions
#define MEMCPY REGION_CONST(0x2fcc28, 0x2f3bdc, 0x2f3bdc)
#define MTCTRHEAPALLOCATOR_MALLOC REGION_CONST(0x4273d4, 0x43ee50, 0x43ee50)
#define MTEXHEAPALLOCATOR_MALLOC REGION_CONST(0x569810, 0x582c98, 0x582c98)
#define GSPGPU_FLUSHDATACACHE REGION_CONST(0x7fb610, 0x817044, 0x817044)
#define GX_TEXTURECOPY REGION_CONST(0x7fb77c, 0x8171b0, 0x8171b0)
#define LDRRO_LOADCRO REGION_CONST(0x70b1e0, 0x726968, 0x726968)
#define SVC_SLEEPTHREAD REGION_CONST(0x116170, 0x12112c, 0x12112c)
#define SVC_EXITPROCESS REGION_CONST(0x2f9304, 0x2efcfc, 0x2efcfc)
// instances
#define MTCTRHEAPALLOCATOR_INSTANCE_PTR REGION_CONST(0xe1c0dc, 0xe06ee4, 0xe06ee4)
#define MTEXHEAPALLOCATOR_INSTANCE_PTR MTCTRHEAPALLOCATOR_INSTANCE_PTR + 8
// service handles
#define GSPGPU_HANDLE_PTR REGION_CONST(0xddc4d4, 0xdc627c, 0xdc627c)
#define FSUSER_HANDLE_PTR REGION_CONST(0xdcee20, 0xdb82e8, 0xdb82e8)
#define LDRRO_HANDLE_PTR REGION_CONST(0xdcf8c0, 0xdb91a4, 0xdb91a4)
#define SRV_HANDLE_PTR REGION_CONST(0xddccd0, 0xdc6a78, 0xdc6a78)
// linear offsets
#define CODEBIN_SIZE REGION_CONST(0xd00000, 0xcea000, 0xcea000)
#define BSS_SIZE REGION_CONST(0x5d818, 0x721cc, 0x721cc)
#define STACK_SIZE REGION_CONST(0x10000, 0x10000, 0x10000)
#define HEAP_SIZE REGION_CONST(0x813000, 0x846000, 0x846000)
#define CODEBIN_START_LINEAR 0x37c00000 - CODEBIN_SIZE
#define HEAP_START_LINEAR CODEBIN_START_LINEAR - (BSS_SIZE & ~0xfff) - STACK_SIZE - HEAP_SIZE
#define CRR_START_LINEAR REGION_CONST(HEAP_START_LINEAR+0x80000+0x6de000, HEAP_START_LINEAR+0xb2000+0x6ef000, HEAP_START_LINEAR+0xb2000+0x6ee000)
// other
#define NULLSUB_PTR_PTR REGION_CONST(0x9d1700, 0x9ee44c, 0x9ee414)
#define EXTDATA_ID REGION_CONST(0x1554, 0x185b, 0x1870)
#define OTHERAPP_VA 0x101000
#define ICACHE_SIZE 0x8000
#define CRO_MAP_FIX 0x8000000 - (0x100000 + CODEBIN_SIZE + (BSS_SIZE & ~0xfff))
#define HID_SHARED_MEM 0x10000000
// texture file settings
#define MIPMAP_COUNT 11
#define TEXTURE_COUNT 252
#define MTFILEREADER_INSTANCE 0x410
#define ROP_START 0x460 + (9 * 4)
#define TEX_FILE_SIZE MIPMAP_COUNT * TEXTURE_COUNT * 4 + 0x10


assume cs:code,ds:data,ss:stack

data 		segment
						;存放常量内存区域
						db	'SCORE:',0
						db	'LEVEL:',0
						db	'DELROW:',0
						db	'TIME:',0
						db	'=','|',0,0

						;用来显示数字 ，内存 为 12 分 则内存中为 0CH
						;即：C / 10 = 2 ，1 / 10 = 1 .则内存中 ds:[1] = 1 ds:[2] = 2 直接取出字符串
num_str					db	'0','1','2','3','4','5','6','7','8','9'

							;E黄色D 红色B 亮绿色A 绿色6 橙色7 暗黄色8 灰色
color					db	0EH,0DH,0BH,0AH,6,7,8

						;0显示方块1分数2难度3消除行数4当前方块5下一个方块E旋转状态
						;67分数显存地址89难度显存AB消除行数显示CD时间显存
var						db	3,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1

teris 					dw	5	dup	(0)	;俄罗斯方块的4个点显存位置
teris_old				dw  4	dup (0)	;移动旋转之前的方块显存位置

sys_address				dw	2	dup	(0)	;用来保存系统int9中断的cs，ip

data		ends


stack		segment stack
						db 	128 dup (0)
stack 		ends

code		segment
		start:			mov bx,stack			
						mov ss,bx
						mov bp,128

						call init_reg
						call clear_screen
						call init_screen

						
						
						;call clear_teris

						call save_sys_int9
						call set_new_int9

						call create_teris
						call show_teris
						
						mov cx,1
s2:						call start_game
						mov cx,2
						loop s2
		

quit:					call recover_int9
						mov ax,4C00H
						int 21H

;====================================================
start_game:				
						mov ax,1

						ret
;====================================================
new_int9:				push ax

						in al,60H
						pushf
						call dword ptr sys_address[0]

						cmp al,1
						je quit
						cmp al,200
						je revolve
						cmp al,203
						je left
						cmp al,208
						je down
						cmp al,205
						je right
						jmp int9Ret

revolve:				call revolve_teris
						jmp int9Ret

right:					call move_right
						jmp int9Ret

left:					call move_left
						jmp int9Ret

down:					call move_down
						jmp int9Ret

int9Ret:				pop ax
						iret

new_int9_end:			nop
;====================================================
recover_int9:			push ax
						push es

						mov ax,0
						mov es,ax

						push sys_address[0]
						pop es:[9*4]
						push sys_address[2]
						pop es:[9*4+2]
						mov word ptr sys_address[0],0
						mov word ptr sys_address[2],0

						pop es
						pop ax
						ret
;====================================================
set_new_int9:			push bx
						push es

						mov bx,0
						mov es,bx
						cli
						mov word ptr es:[9*4],OFFSET new_int9
						mov word ptr es:[9*4+2],cs
						sti

						pop es
						pop bx
						ret
;====================================================
;保存系统int9
;参数：无
;返回值：无
;说明：将系统int9 中断指令cs，ip 保存到内存sys_address中
save_sys_int9:			push bx
						push es

						mov bx,0
						mov es,bx
						cli 
						push es:[9*4]
						pop sys_address[0]
						push es:[9*4+2]
						pop sys_address[2]
						sti

						pop es
						pop bx
						ret
;====================================================
;取随机数
;参数： dl
;返回值： bl
;说明： 取0-dl 范围随机数，取时钟计时器值，取余得随机数
rand:					push ax
						push dx
						push cx

						push dx
						sti 
						mov ah,0	;读时钟计数器
						int 1AH
						mov ax,dx
						mov ah,0	;高位清0 此时 al 范围 0-255
						pop dx
						div dl		;除dl 获取 0-dl 范围内的余数
						
						mov bx,0
						mov bl,ah 	;ah 中余数 存 bl中，作为随机数使用

						pop cx
						pop dx
						pop ax
						ret 
;====================================================
move_right:				
						ret
;====================================================
move_left:				
						ret
;====================================================
move_down:									
						ret
;====================================================
;创建俄罗斯方块
;参数：无
;返回值：无 （修改内存区域 teris）
;说明：俄罗斯方块共5个点，第一个点为最下方最左边的参考点 L1:DCH	
create_teris:			push dx
						push bx

						mov word ptr teris[2],226H
						mov dx,0
						mov dl,7
						call rand
						mov byte ptr var[4],bl

						

createT:				cmp bl,0
						jne createJ
						mov word ptr teris[0],226H-2
						mov word ptr teris[4],226H-2
						mov word ptr teris[6],226H+2
						mov word ptr teris[8],226H-0A0H
						jmp createTerisRet

createJ:				cmp bl,1
						jne createL
						mov word ptr teris[0],226H-2+0A0H
						mov word ptr teris[4],226H-2
						mov word ptr teris[6],226H+2
						mov word ptr teris[8],226H+2+0A0H
						jmp createTerisRet

createL:				cmp bl,2
						jne createS
						mov word ptr teris[0],226H-2
						mov word ptr teris[4],226H-2
						mov word ptr teris[6],226H+2
						mov word ptr teris[8],226H+2-0A0H
						jmp createTerisRet

createS:				cmp bl,3
						jne createI
						mov word ptr teris[0],226H-2
						mov word ptr teris[4],226H-2
						mov word ptr teris[6],226H-0A0H
						mov word ptr teris[8],226H+2-0A0H
						jmp createTerisRet

createI:				cmp bl,4
						jne createO
						mov word ptr teris[0],226H-2
						mov word ptr teris[4],226H-2
						mov word ptr teris[6],226H+2
						mov word ptr teris[8],226H+4
						jmp createTerisRet

createO:				cmp bl,5
						jne createZ
						mov word ptr teris[0],226H
						mov word ptr teris[4],226H+2
						mov word ptr teris[6],226H-0A0H
						mov word ptr teris[8],226H+2-0A0H
						jmp createTerisRet

createZ:				mov word ptr teris[0],226H-2
						mov word ptr teris[4],226H-2-0A0H
						mov word ptr teris[6],226H-0A0H
						mov word ptr teris[8],226H+2
						jmp createTerisRet

createTerisRet:			pop bx
						pop dx
						ret
;===================================================
show_teris:				push bx
						push cx
						push si
						push di

						mov si,2

						mov bx,0
						mov bl,byte ptr var[4]
						mov bh,color[bx]
						mov bl,byte ptr var[0]
						mov cx,4

showTeris:				mov di,word ptr teris[si]
						mov es:[di],bl
						inc di
						mov es:[di],bh	
						mov ch,0
						add si,2
						loop showTeris 

						pop di
						pop si
						pop cx
						pop bx
						ret
;====================================================
;消除移动旋转前的俄罗斯方块
;参数：无
;返回值：无
clear_teris:			push cx
						push bx
						push si
						push ax

						mov ax,0
						mov cx,5
						mov si,0

clearTeris:				mov bx,word ptr teris[si]
						mov word ptr teris[si],0
						mov word ptr es:[bx],0700H
						add si,2
						loop clearTeris	

						pop ax
						pop si
						pop bx
						pop cx
						ret
;====================================================
;检查边界
;参数：无
;返回值：true：al=7DH  false:2FH
;检查teris 区中的teris 是否产生碰撞
check_boundary:			push ax
						push cx
						push si
						push di

						mov cx,4
						mov si,2

checkBoundary:			mov di,word ptr teris[si]
						mov al,byte ptr es:[di]
						cmp al,0
						jne collision
						add si,2
						loop checkBoundary

						mov al,2FH
						jmp checkBoundaryRet

collision:				mov al,7DH
						jmp checkBoundaryRet

checkBoundaryRet:		pop di
						pop si
						pop cx
						pop ax
						ret
;====================================================
revolve_teris:			push di
						push ax
						
						mov di,0
						mov al,'u'
						mov es:[di],al

						pop ax
						pop di
						ret
;===================================================
;初始化游戏屏幕
;参数：无
;返回值：无
;说明：屏幕上边框左边坐标点 L1:160+60 L2:160*21 R1:160+60+22 R2:160*21+60+22
;						L1:	DCH		L2:	D20H	R1:	F2H		R2:D78H
init_screen:			push si
						push di
						push cx
						push bx
						push es
						push ds

						mov si,1CH
						mov di,160 * 1 + 60
						push di
						mov cx,11

showHorizontalFrame:	mov bl,ds:[si]
						mov es:[di],bl
						mov es:[di+160*21],bl
						add di,2
						loop showHorizontalFrame

						inc si
						pop di			
						mov cx,22

showVerticalFrame:		mov bl,ds:[si]
						mov es:[di],bl
						mov es:[di+11*2],bl
						add di,160
						loop showVerticalFrame

						mov di,160 * 5 + 60 + 15 * 2 ; 第6行 游戏框右面空3格显示
						mov si,0
						mov cx,4
			
showLetter:				push cx
						mov cx,0
						add di,160
						mov bx,0

setLetter:				mov cl,ds:[si]
						jcxz showRowLetterOver
						mov es:[di+bx],cl
						add bx,2
						inc si
						loop setLetter

showRowLetterOver:		pop cx
						push si			;将分数等显存地址存入内存
						mov si,0EH
						sub si,cx
						sub si,cx
						mov dx,di
						add dx,bx
						add dx,2
						mov word ptr var[si],dx
						pop si
						inc si
						jcxz initNumber
						loop showLetter

initNumber:				mov cx,3		;显示分数等信息
						mov bx,1
s:						call show_number
						inc bx
						loop s
			
initScreenRet:			pop ds
						pop es	
						pop bx
						pop cx
						pop di
						pop si
						ret
;====================================================
;显示数字
;参数：bx
;返回值：无
;说明：显示SCORE（bx=1）、LEVEL（bx=2）、DELROW（bx=3） 后数字信息
show_number:			push ax
						push di
						push si
						push dx
						push bx

						mov ax,0
						mov dx,0
						mov al,byte ptr var[bx]
						add bx,bx
						add bx,4
						mov di, word ptr var[bx]
						add di,4
						mov bx,0
						
parseNumber:			mov dl,10
						div dl
						mov bl,ah
						mov dh,byte ptr num_str[bx]
						mov es:[di],dh
						mov dh,0
						sub di,2
						mov ah,0
						cmp al,0
						je showNumberRet
						jmp parseNumber

showNumberRet:			pop bx
						pop dx
						pop si
						pop di
						pop ax
						ret
;====================================================
;初始化寄存器
;参数：无
;返回值：es、ds
init_reg:				mov bx,data
						mov ds,bx
						mov bx,0B800H
						mov es,bx
						ret
;====================================================
;清理屏幕
;参数：无
;返回值：无
clear_screen:			push bx
						push dx
						push cx
						push es		

						mov bx,0B800H
						mov es,bx
						mov bx,0
						mov dx,0700H
						mov cx,2000

clearScreen:			mov es:[bx],dx
						add bx,2
						loop clearScreen
						
						pop es
						pop cx
						pop dx
						pop bx
						ret
;====================================================
code 		ends
end 		start

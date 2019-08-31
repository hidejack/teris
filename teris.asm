assume cs:code,ds:data,ss:stack

data 		segment
						;存放常量内存区域
						db	'SCORE:',0
						db	'LEVEL:',0
						db	'DELROW:',0
						db	'NEXT:',0
						db	'=','|',0,0

						;用来显示数字 ，内存 为 12 分 则内存中为 0CH
						;即：C / 10 = 2 ，1 / 10 = 1 .则内存中 ds:[1] = 1 ds:[2] = 2 直接取出字符串
num_str					db	'0','1','2','3','4','5','6','7','8','9'

							;E黄色D 红色B 亮绿色A 绿色6 橙色7 暗黄色8 灰色
color					db	0EH,0DH,0BH,0AH,6,7,3

						;0显示方块1分数2难度3消除行数4当前方块5下一个方块E旋转状态
						;67分数显存地址89难度显存AB消除行数显示CD时间显存
var						db	3,0,1,0,0,6,0,0,0,0,0,0,0,0,0,1

teris 					dw	5	dup	(0)	;俄罗斯方块的4个点显存位置
teris_old				dw  5	dup (0)	;移动旋转之前的方块显存位置

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
						call init_var
						call show_number

						call save_sys_int9
						call set_new_int9

						call create_teris
						call show_teris

						;call revolve_teris
						;call clear_teris
						;call clear_old_teris_data
						;call show_teris

						;mov di,160*21+62
						;call move_down_all




						mov cx,1
s2:						call start_game
						mov cx,2
						loop s2

quit:					call recover_int9
						mov ax,4C00H
						int 21H

;====================================================
start_game:				push cx

						call delay
						call move_down

						pop cx
						ret
;====================================================
;延时
;参数：无
;返回值：无
delay:					push ax
						push cx
						push dx

						mov ah,86H
						mov cx,0FH
						mov dx,2420
						int 15H

						pop dx
						pop cx
						pop ax
						ret
;====================================================
;自己定义的int9 中断程序
;参数：无
;返回值：无
new_int9:				push ax
						push bx
						push dx

						in al,60H
						pushf									;调用系统int9中断
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

revolve:				mov bl,byte ptr var[4]
						cmp bl,5
						je int9Ret
						call revolve_teris
						jmp checkMove

right:					mov dx,1
						mov ax,0
						call move_action
						jmp checkMove

left:					mov dx,100H
						mov ax,0
						call move_action
						jmp checkMove

down:					call move_down
						jmp int9Ret

checkMove:				call clear_teris
						call check_boundary
						cmp al,'0'
						je toMove
						call recover_teris

toMove:					call clear_old_teris_data
						call show_teris

int9Ret:				pop dx
						pop bx
						pop ax
						iret
;====================================================
move_down:				push dx
						push ax

						mov dx,0
						mov ax,1
						call move_action
						call clear_teris
						call check_boundary
						cmp al,'0'
						je canMoveDown

						call recover_teris
						call clear_old_teris_data
						call show_teris

						call eliminate

						call create_teris
						call show_number
						call show_teris
						jmp moveDownRet

canMoveDown:			call clear_old_teris_data
						call show_teris

moveDownRet:			pop ax
						pop dx
						ret

;====================================================
;程序退出前 恢复系统int9
;参数：无
;返回值：无
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
;修改0:[9*4] 位置 int9 中断程序 cs ip
;参数：无
;返回值：无
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
;保存系统int9 将系统int9 中断指令cs，ip 保存到内存sys_address中
;参数：无
;返回值：无
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
;检查清除填满的行
;参数：无
;返回值：无
;四个点的坐标分别为：160*2+62  160*2+80  160*21+62  160*21+80
eliminate:				push ax
						push bx
						push cx
						push dx
						push di

						mov bl,byte ptr var[5]				;随机生成俄罗斯方块
						mov byte ptr var[4],bl
						mov dx,0
						mov dl,7
						call rand
						mov byte ptr var[5],bl

						mov di,160*21+62
						mov dx,0						;存储消除的行
						mov cx,20

check_row:				push cx
						mov bx,0
						mov cx,10

check_one:				mov al,byte ptr es:[bx+di]
						mov ah,byte ptr var[0]
						cmp al,ah
						jne check_next_row
						add bx,2
						loop check_one
						call clear_row
						call move_down_all
						add di,160						;检查完如果消除1行则需要从这一行继续检查
						pop cx
						inc cx
						push cx
						inc dx

check_next_row:			sub di,160
						pop cx
						loop check_row

						mov bl, byte ptr var[1]			;更新分数和消除行数
						mov al,byte ptr var[3]
						add bl,dl
						add al,dl
						mov byte ptr var[1],bl
						mov byte ptr var[3],al


						pop di
						pop dx
						pop cx
						pop bx
						pop ax
						ret
;====================================================
;整体下移一行
;参数：di 下移起始行
;返回值：无
move_down_all:			push ax
						push bx
						push cx
						push dx
						push di

						mov ax,160*2+62

moveDownAll:			sub di,160
						mov bx,0
						mov cx,10
						mov dx,di
						cmp ax,dx
						je moveDownAllRet

moveRow:				mov dl,byte ptr es:[di+bx]
						mov dh,byte ptr var[0]
						cmp dl,dh
						jne dontSwap

						push word ptr es:[di+bx]
						pop word ptr es:[di+bx+160]
						mov dx,0700H
						mov es:[di+bx],dx

dontSwap:				add bx,2
						loop moveRow
						jmp moveDownAll

moveDownAllRet:			pop di
						pop dx
						pop cx
						pop bx
						pop ax
						ret
;====================================================
;清除一行
;参数：di 行的起始位置
;返回值：无
clear_row:				push ax
						push bx
						push cx

						mov cx,10
						mov ax,0700H
						mov bx,0

clearRow:				mov word ptr es:[di+bx],ax
						add bx,2
						loop clearRow

						pop cx
						pop bx
						pop ax
						ret
;====================================================
;移动
;参数：dh向左 dl向右 al向下
;返回值：无
;说明：dh，dl，al 参数为1表示移动一行 先保存原有坐标 在进行坐标的移动
move_action:			push ax
						push bx
						push cx
						push dx
						push si

						mov si,0
						mov cx,5

moveAction:				push dx
						push ax
						mov bx,teris[si]
						push bx
						pop teris_old[si]		;保存原有地址

						add dh,dh
						add dl,dl

						push dx

						mov dl,dh				;计算左移
						mov dh,0
						sub bx,dx

						pop dx					;计算右移
						mov dh,0
						add bx,dx

						mov dl,160				;计算下移
						mul dl
						add bx,ax
						mov word ptr teris[si],bx	;存储到teris中
						add si,2
						pop ax
						pop dx
						loop moveAction

						pop si
						pop dx
						pop cx
						pop bx
						pop ax
						ret
;====================================================
;清楚old_teris区域中数据
;参数：无
;返回值：无
clear_old_teris_data:	push cx
						push bx
						push si

						mov cx,5
						mov bx,0
						mov si,0
clearOldTeris:			mov teris_old[si],bx
						inc si
						loop clearOldTeris

						pop si
						pop bx
						pop cx
						ret
;====================================================
;恢复teris区域中数据：将old_teris 中数据还给teris
;参数：无
;返回值：无
recover_teris:			push cx
						push si

						mov cx,5
						mov si,0

recoverTeris:			push word ptr teris_old[si]
						pop word ptr teris[si]
						add si,2
						loop recoverTeris

						pop si
						pop cx
						ret
;====================================================
;创建俄罗斯方块
;参数：无
;返回值：无 （修改内存区域 teris）
;说明：俄罗斯方块共5个点，第一个点为最下方最左边的参考点 L1:DCH
create_teris:			push dx
						push bx

						mov word ptr teris[2],226H
						mov bl, byte ptr var[4]

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
						mov word ptr teris[8],226H-0A0H-2
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
;显示俄罗斯方块  teris区域中显存地址
;参数：无
;返回值：无
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
						push dx

						mov cx,4
						mov si,2

clearTeris:				mov bx,word ptr teris_old[si]
						mov dx,0700H
						mov es:[bx],dx
						add si,2
						loop clearTeris

						pop dx
						pop si
						pop bx
						pop cx
						ret
;====================================================
;检查边界
;参数：无
;返回值：上下边框碰撞：bx=7DH 左右边框碰撞：bx=7EH 碰撞方块：bx=7FH 无碰撞:2FH
;检查teris 区中的teris 是否产生碰撞
check_boundary:			push cx
						push si
						push di

						mov cx,4
						mov si,2
						mov bx,0

checkBoundary:			mov di,word ptr teris[si]
						mov al,byte ptr es:[di]
						mov ah,ds:[1CH]
						cmp al,ah
						je bottomCollision
						mov ah,ds:[1DH]
						cmp al,ah
						je sideCollision
						mov ah,var[0]
						cmp al,ah
						je terisCollision

						add si,2
						loop checkBoundary

						mov al,'0'
						jmp checkBoundaryRet

terisCollision:			mov al,'1'
						jmp checkBoundaryRet

bottomCollision:		mov al,'2'
						jmp checkBoundaryRet

sideCollision:			mov al,'3'
						jmp checkBoundaryRet

checkBoundaryRet:		pop di
						pop si
						pop cx
						ret
;====================================================
;旋转
;参数：无
;返回值：无
;说明：1.取方块左下角teris[0]坐标值作为参考点
;2.取每个方块的坐标值
;3.取参考点坐标与显示方块坐标差值绝对值
;4.所得结果行列互换
;5.互换结果加上参考点坐标即为旋转后坐标
revolve_teris:			push ax
						push bx
						push cx
						push dx
						push si

						mov ax,word ptr teris[0]	;取出参考点显存地址
						mov dx,ax
						mov bl,160
						div bl						;此时获取al 为行 ah 为列

						mov cx,4
						mov si,2

revolveTeris:			push ax						;保存参考点坐标
						mov bx,word ptr teris[si]
						mov word ptr teris_old[si],bx
						push ax
						mov ax,bx
						mov bl,160
						div bl
						mov bx,ax					;获取方块坐标存入bx
						pop ax						;取出ax 即参考点坐标

						cmp ah,bh					;获取列差绝对值
						jb bh_ah
						sub ah,bh
						mov bh,ah
						jmp next_value

bh_ah:					sub bh,ah

next_value:				cmp al,bl					;获取行 差绝对值
						jb bl_al
						sub al,bl
						mov bl,al
						jmp get_revolve_address

bl_al:					sub bl,al					;此时绝对值在bx中 bh:列 bl:行

get_revolve_address:	mov ah,0					;获取移动后坐标，此处要进行转换坐标
						mov al,bh
						mov bh,80
						mul bh
						add bl,bl
						mov bh,0
						add ax,bx

						add ax,dx
						mov word ptr teris[si],ax

						add si,2
						pop ax
						loop revolveTeris

						mov word ptr teris_old[0],dx		;将参考点坐标存入old Teris 区域 计算旋转后 参考点
						call get_ref_point
						mov word ptr teris[0],ax

						pop si
						pop dx
						pop cx
						pop bx
						pop ax
						ret
;===================================================
;获取旋转后的参考点
;参数：无
;返回值：ax
;说明：取所有方块的行最大值 列最小值 即为旋转需要获取的参考点 计算地址存入ax 返回
get_ref_point:			push bx
						push cx
						push dx
						push si

						mov dx,0FF00H					;设置dx 为右上角最顶点
						mov si,2
						mov cx,4

getRefPoint:			mov bx,word ptr teris[si]
						mov ax,0
						mov ax,bx
						mov bl,160
						div bl
						cmp dh,ah
						jb getMaxRow
						mov dh,ah

getMaxRow:				cmp al,dl
						jb continue
						mov dl,al

continue:				add si,2
						loop getRefPoint

						mov ax,0
						mov al,dl
						mov bl,160
						mul bl
						mov dl,dh
						mov dh,0
						add ax,dx

						pop si
						pop dx
						pop cx
						pop bx
						ret
;===================================================
;初始化游戏屏幕
;参数：无
;返回值：无
init_screen:			push bx
						push cx
						push dx
						push si
						push di
						push es
						push ds

						mov dx,0					;创建要出现的方块
						mov dl,7
						call rand
						mov byte ptr var[4],bl

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
						;jcxz initNumber
						loop showLetter

						;call show_number

initScreenRet:			pop ds
						pop es
						pop di
						pop si
						pop dx
						pop cx
						pop bx
						ret
;====================================================
init_var:				push bx
						push dx

						mov dx,3
						mov byte ptr var[0],dl
						mov byte ptr var[1],dh
						mov dl,1
						mov byte ptr var[2],dl
						mov dx,0
						mov dl,7
						call rand
						mov byte ptr var[4],bl
						call rand
						mov byte ptr var[5],bl

						pop dx
						pop bx
						ret
;====================================================
;显示数字
;参数：无
;返回值：无
show_number:			push ax
						push di
						push si
						push dx
						push bx
						push cx

						mov cx,3
						mov bx,1

showNumber:				push bx
						mov ax,0
						mov dx,0
						mov al,byte ptr var[bx]
						add bx,bx
						add bx,4
						mov di, word ptr var[bx]		;获取要显示的显存地址
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
						je showRowNumber
						jmp parseNumber

showRowNumber:			pop bx
						inc bx
						loop showNumber

						mov di,word ptr var[0CH]
						add di,160

clearNextTeris:			mov ax,0700H
						mov word ptr es:[di],ax
						mov word ptr es:[di-2],ax
						mov word ptr es:[di+2],ax
						mov word ptr es:[di+4],ax
						mov word ptr es:[di-160],ax
						mov word ptr es:[di-160+2],ax
						mov word ptr es:[di-160-2],ax

showNextTeris:			mov bl,byte ptr var[5]
						mov bh,0
						mov ah,byte ptr color[bx]
						mov al,byte ptr var[0]

						mov word ptr es:[di],ax

createNextT:			cmp bl,0
						jne createNextJ
						mov word ptr es:[di-2],ax
						mov word ptr es:[di+2],ax
						mov word ptr es:[di-160],ax
						jmp showNumberRet

createNextJ:			cmp bl,1
						jne createNextL
						mov word ptr es:[di-2],ax
						mov word ptr es:[di+2],ax
						mov word ptr es:[di-160-2],ax
						jmp showNumberRet

createNextL:			cmp bl,2
						jne createNextS
						mov word ptr es:[di-2],ax
						mov word ptr es:[di+2],ax
						mov word ptr es:[di+2-160],ax
						jmp showNumberRet

createNextS:			cmp bl,3
						jne createNextI
						mov word ptr es:[di-2],ax
						mov word ptr es:[di-160],ax
						mov word ptr es:[di+2-160],ax
						jmp showNumberRet

createNextI:			cmp bl,4
						jne createNextO
						mov word ptr es:[di-2],ax
						mov word ptr es:[di+2],ax
						mov word ptr es:[di+4],ax
						jmp showNumberRet

createNextO:			cmp bl,5
						jne createNextZ
						mov word ptr es:[di+2],ax
						mov word ptr es:[di+2-160],ax
						mov word ptr es:[di-160],ax
						jmp showNumberRet

createNextZ:			mov word ptr es:[di-160],ax
						mov word ptr es:[di-160-2],ax
						mov word ptr es:[di+2],ax
						jmp showNumberRet


showNumberRet:			pop cx
						pop bx
						pop dx
						pop si
						pop di
						pop ax
						ret
;====================================================
;初始化寄存器
;参数：无
;返回值：es、ds
init_reg:				push bx
						mov bx,data

						mov ds,bx
						mov bx,0B800H
						mov es,bx
						pop bx
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
